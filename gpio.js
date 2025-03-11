const baseAddress = "http://127.0.0.1:8080";

// Local deployment
// const hofServiceUrl = `${baseAddress}/hall_of_fame`;
// const logCompletionUrl = `${baseAddress}/level_completion`;

// Cloud deployment
const hofServiceUrl = "https://5acun5rqdkalcagdfpldl47aki0xkwwe.lambda-url.eu-west-1.on.aws/";
const logCompletionUrl = "https://roe3f4jh6uab4rnvjzr7ajap2a0fjhxr.lambda-url.eu-west-1.on.aws/";

const tableId = "test";

const gpioReadAddress = 0;
const gpioWriteAddress = 64;
const gpioBlockSize = 63;
const hofSize = 24;

var sokobubbleHOF = Array(hofSize).fill(null).map(_ => ["-", 999]);
var gpioConnected = false;
var gpioTxtIn = "";
var gpioTxtOut = undefined;

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

async function logLevelCompletion(level, moveCount, player, moveHistory) {
    const response = await fetch(logCompletionUrl, {
        method: 'POST',
        body: JSON.stringify({ level, player, moveCount, moveHistory, tableId }),
        headers: {
          'Content-Type': 'application/json'
        }
      });
    if (!response.ok || response.status != 200) {
        console.warn("Failed to post level completion");
        console.info(response);

        // TODO: Add retry with back-off incase of status 503

        return
    }

    const responseJson = await response.json(); //extract JSON from the http response

    const levelEntry = sokobubbleHOF[level - 1];
    levelEntry[0] = responseJson.player;
    levelEntry[1] = responseJson.moveCount;

    if (gpioTxtOut !== undefined) {
        console.warn("Cannot send response via GPIO")
    } else {
        // Return (possibly updated) Hall of Fame
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

            // Fire and forget. Do not wait inside this GPIO handler
            logLevelCompletion(parseInt(levelIdx), parseInt(numMoves), playerName, moves);
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

function makeHOFString(hof) {
    return hof.map(v => v.join()).join();
}

async function fetchHallOfFame() {
    const response = await fetch(hofServiceUrl);
    const responseJson = await response.json(); //extract JSON from the http response
    const hof = responseJson.hallOfFame;

    for (let i = 0; i < hofSize; i++) {
        const entry = hof[(i + 1).toString()];
        if (entry !== undefined) {
            sokobubbleHOF[i] = [entry.player, entry.moveCount];
        }
    }

    gpioTxtOut = makeHOFString(sokobubbleHOF);
    console.info(`Fetched Hall of Fame: ${gpioTxtOut}`);
}

window.setInterval(gpioUpdate, 100);

fetchHallOfFame();
