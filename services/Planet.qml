pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// The brain of the page rotation. Stand-ins take the place of the real windows,
// Hyprland switches page behind them, and the planet spins them into view.
Singleton {
    id: root

    enum Phase {
        Idle,
        Preparing,
        Spinning,
        Settling,
        Orbit
    }

    readonly property real step: Math.PI * 2 / Config.pages
    readonly property int current: Hyprland.focusedWorkspace?.id ?? 1
    readonly property int lastPage: Config.pages * 10
    // The group of pages the bar shows, and the one carried around the planet in orbit
    readonly property int groupStart: groupOf(current)
    property int orbitStart: 1
    readonly property bool pageEmpty: Hyprland.toplevels.values.every(t => t.workspace?.id !== current)

    property int phase: Planet.Phase.Idle
    property real resting: 0 // where the planet sits between two transitions
    property real travel: 0 // how far it has turned so far
    property real distance: 0 // how far it has to turn in total
    readonly property real remaining: distance - travel

    property var leaving: []
    property var leavingNext: []
    property string birthing: "" // the window currently being born, if any
    property var arriving: []
    property int captured: 0
    property int expected: 0
    property real sceneOpacity: 1

    property int origin: 1
    // Altitude: 0 is the ground, 1 is orbit
    property real altitude: 0
    property var orbitPages: []
    property bool goingUp: false
    readonly property bool orbiting: phase === Planet.Phase.Orbit

    // One level above orbit: every planet you could live on
    property bool inSystem: false
    property real systemLevel: 0
    property real systemScroll: 0 // how far along the row of planets we are, between two of them while dragging
    readonly property int systemChoice: {
        const count = Planets.solar.length;
        return (Math.round(systemScroll) % count + count) % count;
    }

    // Whatever comes to the front gets tried on by the whole shell
    onSystemChoiceChanged: {
        if (inSystem)
            Config.preview = Planets.solar[systemChoice];
    }

    // Turning the planet by hand, up in orbit
    property real handTurn: 0
    property int hoveredPage: -1
    readonly property int topPage: orbitStart + ((origin - orbitStart - Math.round(handTurn / step)) % Config.pages + Config.pages) % Config.pages

    property int target: 0
    property int queued: 0
    property var layouts: ({}) // what each page looked like when we last took its photo
    property var photoOwner: ({}) // photos are kept per slot of a group, this says whose each one is
    property bool arrivalKnown: false
    property real pressedAt: 0

    // While a page turns, focus lands at once: the window arriving behind the scene is
    // already lit when the scene steps aside, instead of fading in right in front of you.
    // Ordinary focus changes keep their slow fade.
    readonly property bool focusQuiet: phase !== Planet.Phase.Idle
    property bool quieted: false
    readonly property string fadesOff: 'for _, leaf in ipairs({ "fadeSwitch", "fadeDim", "fadeShadow", "border" }) do hl.animation({ leaf = leaf, enabled = false }) end'
    readonly property string fadesOn: `for _, leaf in ipairs({ "fadeSwitch", "fadeDim", "fadeShadow", "border" }) do hl.animation({ leaf = leaf, enabled = true, speed = ${Theme.windowFocusSpeed}, bezier = "eteaFocus" }) end`

    function quiet() {
        if (fades.running || quieted === focusQuiet)
            return;
        quieted = focusQuiet;
        fades.command = ["hyprctl", "eval", quieted ? fadesOff : fadesOn];
        fades.running = true;
    }

    onFocusQuietChanged: quiet()

    // Turning the planet with the fingers: it follows the swipe, and only on letting go
    // does Hyprland change page, or the planet rolls back if it wasn't far enough
    property bool following: false // a swipe is under way
    property bool fingerDriven: false // this page change is the swipe's, not a key's
    property real swiped: 0 // how far the fingers have gone, in Hyprland's swipe units
    property real swipeSpeed: 0 // units per second, at the last update
    property real swipeTime: 0
    property int swipeDirection: 0 // +1 towards the next page, -1 the previous one
    property var swipeEnd: null // let go before the stand-ins were ready: { commit }
    readonly property real swipeDistance: 620 // a full page, in swipe units
    readonly property real swipeProgress: swipeDirection === 0 ? 0 : Math.max(0, Math.min(1, -swiped * swipeDirection / swipeDistance))

    function swipeStart() {
        if (phase !== Planet.Phase.Idle)
            return;
        following = true;
        swiped = 0;
        swipeSpeed = 0;
        swipeTime = Date.now();
        swipeDirection = 0;
        swipeEnd = null;
    }

    function swipeMove(dx) {
        if (!following)
            return;
        // Speed smoothed over the last few moves: one quick event isn't a flick
        const now = Date.now(), instant = dx / Math.max(8, now - swipeTime) * 1000;
        swiped += dx;
        swipeSpeed = swipeSpeed * 0.7 + instant * 0.3;
        swipeTime = now;
        // The first clear move picks the way: fingers to the left go to the next page
        if (swipeDirection === 0 && Math.abs(swiped) > 14) {
            const way = swiped < 0 ? 1 : -1, page = current + way;
            if (page < 1 || page > lastPage) {
                following = false;
                return;
            }
            swipeDirection = way;
            fingerDriven = true;
            request(page);
        }
        if (fingerDriven && phase === Planet.Phase.Spinning && !glide.running)
            travel = swipeProgress * distance;
    }

    function swipeFinish(cancelled) {
        if (!following)
            return;
        following = false;
        if (!fingerDriven)
            return;
        // Far enough, or flicked that way: go. Otherwise the planet rolls back. Fingers that
        // stopped before letting go aren't flicking anything.
        const flick = Date.now() - swipeTime > 90 ? 0 : -swipeSpeed * swipeDirection;
        const commit = !cancelled && (swipeProgress > 0.33 || (flick > 1400 && swipeProgress > 0.08));
        if (phase === Planet.Phase.Spinning)
            letGoOfSwipe(commit);
        else
            swipeEnd = { commit: commit };
    }

    function letGoOfSwipe(commit) {
        swipeEnd = null;
        if (commit)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${target} })`);
        glide.stop();
        glide.committed = commit;
        glide.from = travel;
        glide.to = commit ? distance : 0;
        // The rest of the way at the speed the fingers had, never sluggish
        glide.duration = Math.max(140, Theme.pageSpin * 0.8 * Math.abs(glide.to - travel) / Math.max(0.001, Math.abs(distance)));
        glide.start();
    }

    signal photoNeeded(int page, int slot)
    signal worldWanted(string id) // a new world picked outside orbit, the stage wipes it in
    signal finished(real prepareMs)

    // Everything that wants to change page comes through here
    function request(page) {
        if (page < 1 || page > lastPage)
            return;
        if (phase !== Planet.Phase.Idle) {
            queued = page;
            return;
        }
        if (page === current)
            return;
        // Hyprland's own slide, to compare: it does it all
        if (Config.pageTransition === "slide") {
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${page} })`);
            return;
        }

        origin = current;
        target = page;
        pressedAt = Date.now();
        captured = 0;
        phase = Planet.Phase.Preparing;
        Hyprland.refreshToplevels();
        geometryDelay.restart();
    }

    // Where the pages sit in the bar on the focused screen. The bar keeps it up to date.
    property rect pagesArea: Qt.rect(Theme.barSide, Theme.barGap, 0, Theme.barHeight)

    // The middle of a page's constellation in the bar
    function pagePoint(page) {
        const place = Math.max(0, Math.min(Config.pages - 1, page - groupStart));
        return Qt.point(pagesArea.x + place * (Theme.pageWidth + Theme.pageGap) + Theme.pageWidth / 2, pagesArea.y + pagesArea.height * 0.6);
    }

    function groupOf(page) {
        return Math.floor((page - 1) / Config.pages) * Config.pages + 1;
    }

    function slotOf(page) {
        return (page - 1) % Config.pages;
    }

    function askPhoto(page) {
        photoOwner[slotOf(page)] = page;
        photoNeeded(page, slotOf(page));
    }

    function hasPhoto(page) {
        return photoOwner[slotOf(page)] === page;
    }

    // Going up: ground, then orbit, then the whole system, then back home
    function toggleOrbit() {
        // Super+Tab одразу показує Сонячну систему, ще раз -- назад на поточний стіл
        if (phase === Planet.Phase.Idle)
            enterOrbit();
        else if (orbiting)
            landPage(current);
    }

    // One level down at a time
    function goDown() {
        if (orbiting)
            landPage(current);
    }

    // Час шейдера теми "Глибокий космос": один на всі копії фону
    property real deepTime: 0

    IpcHandler {
        target: "deep"

        function set(id: string): void {
            Config.deepSpace = id === "off" ? "" : id;
        }

        function rotate(): void {
            Config.deepAngle += Math.PI / 2;
        }

        function state(): string {
            return Config.deepSpace || "off";
        }
    }

    function holdSpin() {
        spinShift.stop();
    }

    // Let go and the planet keeps going a little, then settles on the nearest page
    function fling(speed) {
        spinTo(Math.round((handTurn + speed * 0.28) / step) * step);
    }

    function nudge(steps) {
        spinTo((Math.round(handTurn / step) + steps) * step);
    }

    function spinTo(angle) {
        spinShift.stop();
        spinShift.to = angle;
        spinShift.start();
    }

    function refreshOrbit() {
        Hyprland.refreshToplevels();
        orbitRefresh.restart();
    }

    function enterSystem() {
        systemSlide.stop();
        systemScroll = Math.max(0, (current - 1) % Planets.solar.length);
        Config.preview = Planets.solar[systemChoice];
        inSystem = true;
        systemShift.to = 1;
        systemShift.restart();
    }

    function leaveSystem() {
        Config.preview = "";
        inSystem = false;
        systemShift.to = 0;
        systemShift.restart();
    }

    function chooseStep(step) {
        slideSystemTo((systemSlide.running ? systemSlide.to : Math.round(systemScroll)) + step);
    }

    function slideSystemTo(position) {
        systemSlide.stop();
        systemSlide.to = position;
        systemSlide.start();
    }

    // The row of planets follows the hand, in planets rather than pixels
    function dragSystem(change) {
        systemSlide.stop();
        systemScroll += change;
    }

    // Let go and it carries on a little, then settles on the nearest planet
    function releaseSystem(speed) {
        slideSystemTo(Math.round(systemScroll + speed * 0.22));
    }

    // A world picked from Settings: the focused stage freezes the screen, the new world
    // settles in behind, and a star wipes it in. Nothing to freeze, it simply changes.
    function changeWorld(id) {
        if (id === Config.theme)
            return;
        if (phase !== Planet.Phase.Idle) {
            Config.theme = id;
            return;
        }
        worldWanted(id);
    }

    // Вибір столу в Сонячній системі: летимо на його планету
    function landPage(page) {
        leaveSystem();
        leaveOrbit(page);
    }

    // Moving to a new planet: the theme changes and we come down onto it
    function land(id) {
        Config.theme = id;
        leaveSystem();
        leaveOrbit(current);
    }

    // Same trick as a page change: photograph this page, then the stand-ins take over
    function enterOrbit() {
        origin = current;
        orbitStart = groupOf(current);
        target = current;
        goingUp = true;
        captured = 0;
        phase = Planet.Phase.Preparing;
        Hyprland.refreshToplevels();
        orbitDelay.restart();
    }

    function beginOrbit() {
        captureTimeout.stop();
        goingUp = false;
        phase = Planet.Phase.Orbit;
        rise.restart();
        enterSystem();
    }

    // Going back down, turning to the chosen page on the way
    function leaveOrbit(page) {
        if (!orbiting || descent.running)
            return;
        target = page;
        spinShift.stop();
        rise.stop(); // going back down halfway up, the two movements mustn't fight
        const turn = shortestSteps(origin, page) * step + handTurn;
        distance = Math.atan2(Math.sin(turn), Math.cos(turn));
        // Letting go of the keyboard makes Hyprland refocus the old window, which would
        // pull us straight back to the old page. So let go first, then change page.
        phase = Planet.Phase.Spinning;
        descent.restart();
        if (page !== current)
            orbitLanding.restart();
    }

    // The pages stay up until the scene has stepped aside, or the windows would blink out.
    // From here on the page we landed on is the one at the top of the planet.
    function landed() {
        origin = target;
        // On an empty page Hyprland has nothing to focus and can drift back, so insist
        if (current !== target)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${target} })`);
        settle();
    }

    // No looping round: page 1 is the first, and past the end of a group comes the next one
    function requestNext(direction) {
        request(current + direction);
    }

    // Stacked the way they are on screen, and a maximized window hides the others
    function windowsOn(page) {
        const list = Hyprland.toplevels.values.filter(t => t.workspace?.id === page && t.lastIpcObject?.size);
        const full = list.find(t => t.lastIpcObject.fullscreen > 0);
        if (full)
            return [full];
        return list.sort((a, b) => b.lastIpcObject.focusHistoryID - a.lastIpcObject.focusHistoryID);
    }

    // Two photos match if the same windows sit in the same places
    function layoutOf(windows) {
        return windows.map(t => `${t.address} ${t.lastIpcObject.at} ${t.lastIpcObject.size}`).join("|");
    }

    function noteCaptured() {
        captured += 1;
        if (phase === Planet.Phase.Preparing && captured >= expected)
            goingUp ? beginOrbit() : begin();
    }

    // Stand-ins are ready, so show them, then let Hyprland switch behind them
    function begin() {
        if (phase !== Planet.Phase.Preparing)
            return;
        if (goingUp) {
            beginOrbit();
            return;
        }
        captureTimeout.stop();
        // The stand-ins leaving are cut from the photo, so they wait until it exists
        leaving = leavingNext;
        phase = Planet.Phase.Spinning;
        if (fingerDriven) {
            // The fingers turn it from here; Hyprland stays put until they let go
            finished(Date.now() - pressedAt);
            travel = swipeProgress * distance;
            if (swipeEnd)
                letGoOfSwipe(swipeEnd.commit);
            else if (!following)
                letGoOfSwipe(false);
            return;
        }
        coverDelay.restart();
    }

    // The swipe came back: nothing changed page. The page we started from is the one on
    // screen, so it stays while the scene steps aside; only the page that never came goes.
    function rollBack() {
        arriving = [];
        distance = 0;
        travel = 0;
        hoveredPage = -1;
        phase = Planet.Phase.Settling;
        revealDelay.interval = 40;
        revealDelay.restart();
    }

    function settle() {
        // The old page has left the screen. Drop it now, or it snaps back to the
        // centre once the counters reset, and an empty page wouldn't hide it.
        leaving = [];
        resting += distance - handTurn;
        handTurn = 0;
        hoveredPage = -1;
        distance = 0;
        travel = 0;
        phase = Planet.Phase.Settling;
        // Focus just moved behind the scene. Its fades are off while the page turns (see
        // Illumination), so it's already there: a couple of frames for Hyprland to draw it.
        revealDelay.interval = 40;
        revealDelay.restart();
    }

    function recover() {
        for (const animation of [spin, rise, descent, fade, spinShift, systemShift, systemSlide])
            animation.stop();
        for (const timer of [geometryDelay, orbitDelay, orbitLanding, captureTimeout, coverDelay, revealDelay])
            timer.stop();
        queued = 0;
        travel = 0;
        distance = 0;
        handTurn = 0;
        altitude = 0;
        systemLevel = 0;
        inSystem = false;
        goingUp = false;
        hoveredPage = -1;
        Config.preview = "";
        resting = (current - 1) * step;
        reset();
    }

    function reset() {
        fingerDriven = false;
        swipeEnd = null;
        leaving = [];
        arriving = [];
        orbitPages = [];
        sceneOpacity = 1;
        phase = Planet.Phase.Idle;
        if (queued && queued !== current) {
            const next = queued;
            queued = 0;
            request(next);
        }
        queued = 0;
    }

    // How far the planet turns for a page change: one step per page, at most half a turn
    function spinSteps(from, to) {
        const half = Math.floor(Config.pages / 2);
        return Math.max(-half, Math.min(half, to - from));
    }

    // Shortest way round the planet in orbit, where the pages of a group sit in a ring
    function shortestSteps(from, to) {
        const pages = Config.pages;
        const steps = ((to - from) % pages + pages) % pages;
        return steps > pages / 2 ? steps - pages : steps;
    }

    // Give the window list a moment to come back from Hyprland
    Timer {
        id: geometryDelay

        interval: 12
        onTriggered: {
            root.distance = root.spinSteps(root.origin, root.target) * root.step;
            const leaving = root.windowsOn(root.origin);
            root.leavingNext = leaving;
            root.arriving = root.windowsOn(root.target);

            // Coming back to a page that hasn't changed? Its old photo is still good
            const arrival = root.layoutOf(root.arriving);
            root.arrivalKnown = root.arriving.length > 0 && root.layouts[root.target] === arrival && root.hasPhoto(root.target);
            root.expected = (leaving.length ? 1 : 0) + (root.arrivalKnown ? 0 : root.arriving.length);

            if (leaving.length) {
                root.layouts[root.origin] = root.layoutOf(leaving);
                root.askPhoto(root.origin);
            }
            if (root.expected === 0)
                root.begin();
            else
                captureTimeout.restart();
        }
    }

    Timer {
        id: orbitDelay

        interval: 12
        onTriggered: {
            const pages = [];
            for (let page = root.orbitStart; page < root.orbitStart + Config.pages; page++)
                pages.push(root.windowsOn(page));
            root.orbitPages = pages;

            const here = root.windowsOn(root.origin);
            root.expected = here.length ? 1 : 0;
            if (here.length) {
                root.layouts[root.origin] = root.layoutOf(here);
                root.askPhoto(root.origin);
                captureTimeout.restart();
            } else {
                root.beginOrbit();
            }
        }
    }

    Timer {
        id: orbitLanding

        interval: 40
        onTriggered: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${root.target} })`)
    }

    // The scene covers every window while a transition runs, so a transition that gets
    // stuck would hide the whole desktop. However it went wrong, this gives the screen back.
    Timer {
        running: root.phase !== Planet.Phase.Idle && root.phase !== Planet.Phase.Orbit && !root.following
        interval: 6000
        onTriggered: {
            console.warn("ETEA: transition stuck, giving the screen back");
            root.recover();
        }
    }

    NumberAnimation {
        id: spinShift

        target: root
        property: "handTurn"
        duration: 520
        easing.type: Easing.OutCubic
    }

    Timer {
        id: orbitRefresh

        interval: 160
        onTriggered: {
            const pages = [];
            for (let page = root.orbitStart; page < root.orbitStart + Config.pages; page++)
                pages.push(root.windowsOn(page));
            root.orbitPages = pages;
        }
    }

    NumberAnimation {
        id: systemSlide

        target: root
        property: "systemScroll"
        duration: 520
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressive
    }

    NumberAnimation {
        id: systemShift

        target: root
        property: "systemLevel"
        duration: Theme.orbitRise
        easing.type: Easing.InOutCubic
    }

    NumberAnimation {
        id: rise

        target: root
        property: "altitude"
        from: 0
        to: 1
        duration: Theme.orbitRise
        easing.type: Easing.InOutCubic
    }

    ParallelAnimation {
        id: descent

        NumberAnimation {
            target: root
            property: "altitude"
            to: 0
            duration: Theme.orbitRise
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            target: root
            property: "travel"
            from: 0
            to: root.distance
            duration: Theme.orbitRise
            easing.type: Easing.InOutCubic
        }
        onFinished: root.landed()
    }

    // A window that refuses to be captured should never hold the page back
    Timer {
        id: captureTimeout

        interval: 120
        onTriggered: root.begin()
    }

    // Two frames for the stand-ins to reach the screen before the swap
    Timer {
        id: coverDelay

        interval: 34
        onTriggered: {
            root.finished(Date.now() - root.pressedAt);
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${root.target} })`);
            spin.duration = Math.max(1, Theme.pageSpin * (0.75 + 0.25 * Math.abs(root.distance / root.step)));
            spin.from = 0;
            spin.to = root.distance;
            spin.start();
        }
    }

    // Finishing a swipe: on to the page, or back where it started
    NumberAnimation {
        id: glide

        property bool committed: false

        target: root
        property: "travel"
        easing.type: Easing.OutCubic
        onFinished: committed ? root.settle() : root.rollBack()
    }

    NumberAnimation {
        id: spin

        target: root
        property: "travel"
        easing.type: Easing.InOutCubic
        onFinished: root.settle()
    }

    // The wallpaper behind has to catch up before we pull the scene away
    Timer {
        id: revealDelay

        interval: 24
        onTriggered: fade.start()
    }

    NumberAnimation {
        id: fade

        target: root
        property: "sceneOpacity"
        from: 1
        to: 0
        duration: Theme.pageReveal
        onFinished: root.reset()
    }

    // If something else moved us, like a gesture, just follow along
    Connections {
        target: Hyprland

        // The swipe's start, moves and end, sent by the gesture scripts/dev.sh sets up
        function onRawEvent(event) {
            if (event.name !== "custom" || !event.data.startsWith("etea:swipe,"))
                return;
            const [, step, value] = event.data.split(",");
            if (step === "start")
                root.swipeStart();
            else if (step === "move")
                root.swipeMove(Number(value));
            else if (step === "end")
                root.swipeFinish(value === "true");
        }

        function onFocusedWorkspaceChanged() {
            if (root.phase === Planet.Phase.Idle)
                root.resting = (root.current - 1) * root.step;
        }
    }

    Component.onCompleted: resting = (current - 1) * step

    // The phase can flip back faster than hyprctl answers, so catch up once it's done
    Process {
        id: fades

        onExited: root.quiet()
    }
}
