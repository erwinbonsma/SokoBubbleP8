const gpioReadAddress = 0;
const gpioWriteAddress = 64;
const gpioBlockSize = 63;

function makeHOFString(hof) {
    return hof.map(v => v.join()).join();
}

var sokobubbleHOF = Array(24).fill(null).map(_ => ["-", 999]);
sokobubbleHOF[0] = ["bob", 18];
sokobubbleHOF[1] = ["alice", 30];

var gpioConnected = false;
var gpioTxtIn = "";
var gpioTxtOut = makeHOFString(sokobubbleHOF);

function updateHOF(levelIdx, numMoves, playerName) {
    const levelEntry = sokobubbleHOF[levelIdx - 1];
    if (numMoves >= levelEntry[1]) return;

    // Improved score
    levelEntry[0] = playerName;
    levelEntry[1] = numMoves;

    if (gpioTxtOut === undefined) {
        gpioTxtOut = makeHOFString(sokobubbleHOF);
    }
}

function gpioRead() {
    const n = pico8_gpio[gpioReadAddress];
    if (n == 255) {
        // Bootstrap handshake
        gpioConnected = true;
        console.info("GPIO: Connection established");
    } else if (n == 128) {
        console.info(`GPIO: Received ${gpioTxtIn}`);
        const args = gpioTxtIn.split(",");
        if (args.length != 4) {
            console.warn("Unexpected length")
        } else {
            const [levelIdx, numMoves, playerName, moves] = args;
            updateHOF(levelIdx, numMoves, playerName);
        }

        gpioTxtIn = "";
    } else if (n <= gpioBlockSize) {
        for (var i = 1; i <= n; i++) {
            gpioTxtIn += String.fromCharCode(pico8_gpio[gpioReadAddress + i]);
        }
    } else {
        console.warn(`GPIO: Unexpected read size: ${n}`);
    }
    // Release buffer for write
    pico8_gpio[gpioReadAddress] = 0;
}

function gpioWrite() {
    const n = Math.min(gpioBlockSize, gpioTxtOut.length);
    if (n == 0) {
        pico8_gpio[gpioWriteAddress] = 128;
        gpioTxtOut = undefined;
    } else {
        for (var i = 1; i <= n; i++) {
            pico8_gpio[gpioWriteAddress + i] = gpioTxtOut.charCodeAt(i - 1);
        }
        gpioTxtOut = gpioTxtOut.substring(n);
        pico8_gpio[gpioWriteAddress] = n;
        console.info(`GPIO: Wrote ${n} characters`);
    }
}

function gpioUpdate() {
    if (pico8_gpio[gpioReadAddress]) {
        gpioRead();
    }
    if (gpioConnected && pico8_gpio[gpioWriteAddress] == 0 && gpioTxtOut != undefined) {
        gpioWrite();
    }
}

window.setInterval(gpioUpdate, 100);