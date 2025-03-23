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
const hofSizeLevels = 24;
const hofSizeTotals = 10;

// This should match what is sent from PICO-8 client after bootstrap.
// It is duplicated here so that the Hall of Fame can be shown on the HTML page
// when the PICO-8 game is not (yet) started.
var levelIds = [1,2,3,4,6,7,24,8,9,16,17,21,23,10,11,15,12,14,20,26,13,18,19,22];

var bestLevelScores = Array(hofSizeLevels).fill(null).map(_ => ["-", 999]);
var bestTotalScores = Array(hofSizeTotals).fill(null).map(_ => ["-", 24000]);
var playerLevelScores = Array(hofSizeLevels).fill(null).map(_ => 999);
var gpioConnected = false;
var gpioTxtIn = "";
var gpioTxtOut = [];

function sleep(timeMs) {
    return new Promise((resolve) => setTimeout(resolve, timeMs));
}

function updateHtmlTablePartial(hof, elementId, minLevel, maxLevel) {
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

function updateLevelHtmlTable(hof) {
    updateHtmlTablePartial(hof, "HallOfFame-Levels-Left", 1, 12);
    updateHtmlTablePartial(hof, "HallOfFame-Levels-Right", 13, 24);
}

function updateTotalHtmlTable(hof) {
    updateHtmlTablePartial(hof, "HallOfFame-Totals", 1, hofSizeTotals);
}

function updateBestLevelScores(levelRecord, levelIndex) {
    const levelEntry = bestLevelScores[levelIndex - 1];
    levelEntry[0] = levelRecord.player;
    levelEntry[1] = levelRecord.moveCount;

    // Return (possibly updated) Hall of Fame
    sendLevelScores();
    updateLevelHtmlTable(bestLevelScores);
}

function updateBestTotalScores(totalScore, player) {
    if (totalScore === undefined
        || totalScore >= bestTotalScores[bestTotalScores.length - 1]
    ) return;

    let updated = false;
    // Update existing entry if player is already in the Hall of Fame
    for (let i = 0; i < bestTotalScores.length; ++i) {
        if (bestTotalScores[i][0] === player) {
            bestTotalScores[i][1] = totalScore;
            updated = true;
            break;
        }
    }

    if (!updated) {
        // Add player by replacing the last (worse) entry
        bestTotalScores[bestTotalScores.length - 1] = [player, totalScore];
    }

    // Sort by score
    bestTotalScores.sort((a, b) => a[1] - b[1]);

    sendTotalScores();
    updateTotalHtmlTable(bestTotalScores);
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
    console.info(responseJson);

    updateBestLevelScores(responseJson.levelRecord, solveDetails.level);
    updateBestTotalScores(responseJson.moveTotal, solveDetails.player);
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
        } else if (msgId === "levels") {
            if (args.length != hofSizeLevels + 1) {
                console.warn("Unexpected length");
            } else {
                levelIds = Array.from(args.slice(1).map(x => parseInt(x)));
                console.info(`levelIds = ${levelIds}`);

                // This should not have impacted the Hall of Fame, but
                // updating just in case.
                updateLevelHtmlTable(bestLevelScores);
            }
        } else if (msgId === "player") {
            if (args.length != 2) {
                console.warn("Unexpected length");
            } else {
                fetchOnlinePlayerScores(args[1]);
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
    const txtOut = gpioTxtOut[0];
    const n = Math.min(gpioBlockSize, txtOut.length);
    if (n == 0) {
        pico8_gpio[gpioWriteAddress] = 128;
        gpioTxtOut = gpioTxtOut.slice(1);
    } else {
        for (var i = 1; i <= n; i++) {
            pico8_gpio[gpioWriteAddress + i] = txtOut.charCodeAt(i - 1);
        }
        gpioTxtOut[0] = txtOut.substring(n);
        pico8_gpio[gpioWriteAddress] = n;
        console.info(`GPIO: Wrote ${n} characters`);
    }
}

function gpioUpdate() {
    if (pico8_gpio[gpioReadAddress]) {
        gpioRead();
    }
    if (gpioConnected && pico8_gpio[gpioWriteAddress] == 0 && gpioTxtOut.length > 0) {
        gpioWrite();
    }
}

function sendScores(hof, header) {
    const msg = header + hof.map(v => v.join()).join();
    console.info(msg);
    gpioTxtOut.push(msg);
}

function sendLevelScores() {
    sendScores(bestLevelScores, "lvl:");
}

function sendTotalScores() {
    sendScores(bestTotalScores, "tot:");
}

function sendPlayerLevelScores() {
    const msg = "ply:" + playerLevelScores.join();
    console.info(msg);
    gpioTxtOut.push(msg);
}

function handlePlayerLevelScores(scores) {
    for (let i = 0; i < hofSizeLevels; i++) {
        const score = scores[levelIds[i].toString()];
        if (score !== undefined) {
            playerLevelScores[i] = score;
        }
    }

    sendPlayerLevelScores();
}

function handleBestLevelScores(scores) {
    for (let i = 0; i < hofSizeLevels; i++) {
        const entry = scores[levelIds[i].toString()];
        if (entry !== undefined) {
            bestLevelScores[i] = [entry.player, entry.moveCount];
        }
    }

    sendLevelScores();
    updateLevelHtmlTable(bestLevelScores);
}

function handleBestTotalScores(scores) {
    for (let i = 0; i < Math.min(scores.length, hofSizeTotals); i++) {
        bestTotalScores[i] = [scores[i].player, scores[i].moveTotal];
    }

    sendTotalScores();
    updateTotalHtmlTable(bestTotalScores);
}

async function fetchOnlineScores() {
    const response = await fetch(`${queryServiceUrl}?id=${tableId}`);
    const responseJson = await response.json(); //extract JSON from the http response

    handleBestLevelScores(responseJson.levelScores);
    handleBestTotalScores(responseJson.totalScores);
}

async function fetchOnlinePlayerScores(player) {
    const response = await fetch(`${queryServiceUrl}?id=${tableId}&name=${player}`);
    const responseJson = await response.json(); //extract JSON from the http response

    handlePlayerLevelScores(responseJson.playerLevelScores);
}

window.setInterval(gpioUpdate, 100);

fetchOnlineScores();
