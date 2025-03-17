// Local deployment
// const baseAddress = "http://127.0.0.1:8080";
// const hofServiceUrl = `${baseAddress}/hall_of_fame`;
// const logCompletionUrl = `${baseAddress}/level_completion`;

// Cloud deployment
const hofServiceUrl = "https://5acun5rqdkalcagdfpldl47aki0xkwwe.lambda-url.eu-west-1.on.aws/";
const logCompletionUrl = "https://roe3f4jh6uab4rnvjzr7ajap2a0fjhxr.lambda-url.eu-west-1.on.aws/";

const tableId = "live-01";

const gpioReadAddress = 0;
const gpioWriteAddress = 64;
const gpioBlockSize = 63;
const hofSize = 24;

var sokobubbleHOF = Array(hofSize).fill(null).map(_ => ["-", 999]);
var gpioConnected = false;
var gpioTxtIn = "";
var gpioTxtOut = undefined;

function sleep(timeMs) {
    return new Promise((resolve) => setTimeout(resolve, timeMs));
}

function updateHtmlTablePartial(hof, minLevel, maxLevel, elementId) {
    var s = '<table class="hof-table">';
    for (let i = minLevel; i <= maxLevel; i++) {
        const [player, score] = hof[i - 1];
        s += '<tr class="hof-entry">'
            + `<td class="hof-level">${i}.</td>`
            + `<td class="hof-player">${player}</td>`
            + `<td class="hof-score">${score}</td>`
            + '</tr>';
    }
    s += "</table>"

    document.getElementById(elementId).innerHTML = s;
}

function updateHtmlTable(hof) {
    updateHtmlTablePartial(hof, 1, 12, "HallOfFame-Left");
    updateHtmlTablePartial(hof, 13, 24, "HallOfFame-Right");
}

async function logLevelCompletion(solveDetails) {
    const body = JSON.stringify({ ...solveDetails, tableId });

    var attempt = 0;
    var ok = false;
    var response;
    while (!ok) {
        console.info(`Posting level completion: ${body}`);
        response = await fetch(logCompletionUrl, {
            method: 'POST',
            body,
            headers: {
                'Content-Type': 'application/json'
            }
        });
        attempt += 1;
        if (response.ok && response.status === 200) {
            ok = true;
        } else if (response.status === 503) {
            console.warn("Service (temporarily unavailable");

            if (attempt <= 3) {
                const sleepTime = Math.ceil(Math.pow(3, attempt) + Math.random() * 3) * 1000;
                console.info(`Retrying after wait of ${sleepTime}ms`);
                await sleep(sleepTime);
            } else {
                console.info("Giving up");
                return
            }
        } else {
            console.warn(`Unexpected status: ${response.status}`);
            return
        }
    }

    const responseJson = await response.json(); //extract JSON from the http response

    const levelEntry = sokobubbleHOF[solveDetails.level - 1];
    levelEntry[0] = responseJson.player;
    levelEntry[1] = responseJson.moveCount;

    if (gpioTxtOut !== undefined) {
        console.warn("Cannot send response via GPIO")
    } else {
        // Return (possibly updated) Hall of Fame
        gpioTxtOut = makeHOFString(sokobubbleHOF);
    }

    updateHtmlTable(sokobubbleHOF);
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
        const msgId = args[0];
        if (msgId === "result") {
            if (args.length != 6) {
                console.warn("Unexpected length")
            } else {
                const [levelIdx, levelId, player, moveCount, moveHistory] = args.slice(1);

                // Fire and forget. Do not wait inside this GPIO handler
                logLevelCompletion({
                    level: parseInt(levelIdx),
                    levelId: parseInt(levelId),
                    moveCount: parseInt(moveCount),
                    player,
                    moveHistory
                });
            }
        } else {
            console.warn(`Unexpected message: ${msgId}`);
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
    const response = await fetch(`${hofServiceUrl}?id=${tableId}`);
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

    updateHtmlTable(sokobubbleHOF);
}

window.setInterval(gpioUpdate, 100);

fetchHallOfFame();
