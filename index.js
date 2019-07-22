// index.js
'use strict';

// include styles
require('./index.css');
require('./src/Gui/Gui.css');

const deepClone = require('./deep-clone.js');
const randomize = require('./randomize.js');
const buildGradients = require('./gradients.js');
const is = require('./check-layer-type.js');
const drawToCanvas = require('./draw-to-canvas.js');
const JSZip = require('jszip');
const JSZipUtils = require('jszip-utils');
const FileSaver = require('jszip/vendor/FileSaver');
const timing = require('./timing.js');

// initialize Elm Application
const App = require('./src/Main.elm');
//const mountNode = document.getElementById('elm-target');
const mountNode = document.getElementById('js-animation');
// The third value on embed are the initial values for incomming ports into Elm
const app = App.Elm.Main.init({ node: mountNode, flags: { forcedMode: null } });

const startGui = require('./gui.js');
const buildFSS = require('./fss.js');
const nativeMetaballs = require('./native-metaballs.js');

const fssScenes = {};
const allNativeMetaballs = {};

const batchPause = 1000;
let savingBatch = false;

const exportScene = (scene) => {
    return scene.meshes[0].geometry.vertices.map((vertex) => (
        { v0: vertex.v0,
          time: vertex.time,
          anchor: vertex.anchor,
          gradient: vertex.gradient
        }
    ));
}

const prepareModelForImport = (model) => {
    const toSend = deepClone(model);
    toSend.layers =
        model.layers.map(layerDef => {
            const layerDef_ = deepClone(layerDef);
            layerDef_.model = JSON.stringify(layerDef.model);
            return layerDef_;
        });

    return toSend;
}

const import_ = (app, parsedState) => {
    const preparedModel = prepareModelForImport(parsedState);
    app.ports.import_.send(JSON.stringify(preparedModel));

    parsedState.layers.map((layer, index) => {
        if (is.fss(layer)) {
            const fssScene = buildFSS(parsedState, layer.model, layer.sceneFuzz);
            fssScenes[index] = fssScene;
            app.ports.rebuildFss.send({ value: fssScene, layer: index });
        }
    });

    app.ports.pause.send(null);
}

const export_ = (app, exportedState) => {
    app.ports.pause.send(null);
    const stateObj = JSON.parse(exportedState);
    stateObj.layers.forEach((layer, index) => {
        layer.sceneFuzz = is.fss(layer)
            ? exportScene(fssScenes[index]) || exportScene(buildFSS(model, layer.model))
            : null;
    })
    return {
        source: stateObj,
        json: JSON.stringify(stateObj, null, 2)
    };
}

const waitForContent = ({ path, name }) => {
    return new Promise((resolve, reject) => {
        JSZipUtils.getBinaryContent(path, (err, content) => {
            if (err) { reject(err); return; }
            resolve({ path, name, content });
        });
    });
};

const exportZip_ = (app, exportedState) => {
    const sequenceFiles = function (fileList, handler, filesContent) {
        const fileListCopy = fileList.concat([]);
        const nextFilePath = fileListCopy.shift();
        JSZipUtils.getBinaryContent(
            nextFilePath, (err, nextFileContent) => {
                if (err) { throw err; }
                if (!filesContent) { filesContent = {}; };
                filesContent[nextFilePath] = nextFileContent;
                if (fileListCopy.length == 0) {
                    handler(filesContent);
                    return;
                };
                sequenceFiles(fileListCopy, handler, filesContent);
            }
        );
    }

    const PATHS =
        { 'bundle': './player.bundle.js',
          'html': './index.player.html',
          'style': './index.css' };
    const NAMES =
        { 'bundle': 'player.bundle.js',
          'html': 'index.html',
          'style': 'index.css',
          'scene': 'scene.js' };

    sequenceFiles([ PATHS.bundle, PATHS.html, PATHS.style ],
        (files) => {
            const playerBundle = files[PATHS.bundle];
            const playerHtml = files[PATHS.html];
            const playerCss = files[PATHS.style];
            const { json, source }  = export_(app, exportedState);
            const zip = new JSZip();
            zip.file(NAMES.bundle, playerBundle, { binary: true });
            zip.file(NAMES.scene, 'window.jsGenScene = ' + json + ';');
            zip.file(NAMES.html, playerHtml, { binary: true });
            zip.file(NAMES.style, playerCss, { binary: true });
            const assets = zip.folder('assets');
            const assetPromises =
                [ source.product + '-text', 'jetbrains' ]
                    .map(fileName => {
                        return { name: fileName + '.svg'
                               , path : './assets/' + fileName + '.svg'
                               };
                    })
                    .map(waitForContent);
            Promise.all(assetPromises)
                   .then(files =>
                        files.map(
                            ({ content, name }) => {
                                assets.file(name, content, { binary: true }) }
                        )
                    )
                   .then(() => zip.generateAsync({type:"blob"}))
                   .then(content => new FileSaver(content, source.product + "_html5.zip"));
        });
}

const prepareImportExport = () => {
    app.ports.export_.subscribe((exportedState) => {
        const exportCode = export_(app, exportedState).json;

        document.getElementById('export-target').className = 'shown';
        document.getElementById('export-code').value = exportCode;
    });
    app.ports.exportZip_.subscribe((exportedState) => {
        try {
            // console.log('exportedState', exportedState);
            exportZip_(app, exportedState);
        } catch(e) {
            console.error(e);
            alert('Failed to create .zip');
        }
    });
    // document.getElementById('close-export').addEventListener('click', () => {
    //     document.getElementById('export-target').className = '';
    // });
    // document.getElementById('close-import').addEventListener('click', () => {
    //     document.getElementById('import-target').className = '';
    // });
    // setTimeout(() => {
    //     document.getElementById('import-button').addEventListener('click', () => {
    //         document.getElementById('import-target').className = 'shown';
    //     });
    // }, 100);
    // document.getElementById('import').addEventListener('click', () => {
    //     try {
    //         if (document.getElementById('import-code').value) {
    //             const importedScene = JSON.parse(document.getElementById('import-code').value);
    //             import_(app, importedScene);
    //         } else {
    //             alert('Nothing to import');
    //         }
    //     } catch(e) {
    //         console.error(e);
    //         alert('Failed to parse or send, incorrect format?');
    //     }
    // });

}

const savePng = (hiddenLink, { size, coverSize, product, background }) => {
    const [ imageWidth, imageHeight ] = size;
    const srcCanvas = document.querySelector('.webgl-layers');
    const trgCanvas = document.querySelector('#js-save-buffer');
    const [ width, height ] = [ srcCanvas.width, srcCanvas.height ];
    trgCanvas.width = width;
    trgCanvas.height = height;
    if (!srcCanvas || !trgCanvas) return;
    trgCanvas.style.display = 'block';
    trgCanvas.style.backgroundColor = background;
    requestAnimationFrame(() => { // without that, image buffer will be empty
        const trgContext = trgCanvas.getContext('2d');
        trgContext.fillStyle = background;
        trgContext.fillRect(0, 0, width, height);
        trgContext.drawImage(srcCanvas, 0, 0);
        drawToCanvas.html(document.querySelector('.html-layers'), trgCanvas, width, height, () => {

            // FIXME: a temporary hack to draw a logo on the canvas,
            // use product image itself instead
            hiddenLink.download = width + 'x'+ height + '-' + product + '.png';
            drawToCanvas.selector('.product-name-layer', trgCanvas, () => {
                drawToCanvas.selector('.logo-layer', trgCanvas, () => {

                    trgCanvas.toBlob(blob => {
                        const url = URL.createObjectURL(blob);
                        hiddenLink.href = url;
                        hiddenLink.click();
                        URL.revokeObjectURL(url);
                        trgCanvas.style.display = 'none';
                    });

                });
            });

        });
    });
}

prepareImportExport();

const convertRanges = r =>
    {
        return {
            groups : { min : Math.floor(r.minGroups), max: Math.floor(r.maxGroups) },
            balls: { min : Math.floor(r.minBalls), max: Math.floor(r.maxBalls) },
            radius: { min : Math.floor(r.minRadius), max: Math.floor(r.maxRadius) },
            speed: { min : r.minSpeed, max: r.maxSpeed },
            phase: { min : r.minPhase, max: r.maxPhase },
            amplitude:
                {
                    x: { min : r.minAmplitudeX, max: r.maxAmplitudeX },
                    y: { min : r.minAmplitudeY, max: r.maxAmplitudeY }
                }
        };
    }

// document.addEventListener('DOMContentLoaded', () => {
setTimeout(() => {

    const hiddenLink = document.createElement('a');
    hiddenLink.download = 'jetbrains-art-v2.png';

    app.ports.requestFitToWindow.subscribe((_) => {
        app.ports.setCustomSize.send(
            { presetCode: null, viewport: [ window.innerWidth, window.innerHeight ]}
        );
    });

    app.ports.requestWindowResize.subscribe((size) => {
        const [ width, height ] = size;
        // console.log(width, height);
        window.resizeTo(width, height);
    });

    // app.ports.nextBatchStep.subscribe((update) => {
    //     if (savingBatch) {
    //         // console.log('saving ', size);
    //         savePng(hiddenLink, update);
    //     };
    // });

    app.ports.triggerSavePng.subscribe((update) => {
        savePng(hiddenLink, update);
    });

    app.ports.requestRandomize.subscribe((model) => {
        const toSend = deepClone(model);
        toSend.layers = toSend.layers.map((layerDef) => {
            layerDef.model = JSON.parse(layerDef.model);
            return layerDef;
        });
        randomize((randomizedModel) => {
            //const toSend = deepClone(randomizedModel);
            // randomizedModel.layers.forEach((layer) => {
            //     console.log(layer, layer.model);
            // });
            // prepareModelForImport(randomizedModel).layers.forEach((layer) => {
            //     console.log(layer, layer.model);
            // });
            app.ports.applyRandomizer.send(prepareModelForImport(randomizedModel));
        }, toSend, null)({})();
    });

    app.ports.startGui.subscribe(([ model, constants ]) => {
        const altGui = document.getElementById('grid-gui');
        if (altGui) altGui.focus();
        document.body.style.backgroundColor = model.background;

        // console.log('startGui', model);
        model.layers.forEach(layer => {
            layer.model = JSON.parse(layer.model) || {};
        });

        if (!model.mode || (model.mode.substring(0, 4) != 'tron')) {

            const { config, update } = startGui(
                document,
                model,
                constants,
                { changeLightSpeed : index => value =>
                    { app.ports.changeLightSpeed.send({ layer: index, value: Math.round(value) }) }
                , changeVignette : index => value =>
                    { app.ports.changeVignette.send({ layer: index, value: value }) }
                , changeIris : index => value =>
                    { app.ports.changeIris.send({ layer: index, value: value }) }
                , changeFacesX : index => value =>
                    { app.ports.changeFacesX.send({ layer: index, value: Math.round(value) }) }
                , changeFacesY : index => value =>
                    { app.ports.changeFacesY.send({ layer: index, value: Math.round(value) }) }
                , changeRenderMode : index => renderMode =>
                    { app.ports.changeFssRenderMode.send({ layer: index, value: renderMode }) }
                , changeWGLBlend : (index, blend) =>
                    { app.ports.changeWGLBlend.send({ layer: index, value: blend }) }
                , changeHtmlBlend : (index, blend) =>
                    { app.ports.changeHtmlBlend.send({ layer: index, value: blend }) }
                , changeProduct : (id) =>
                    { app.ports.changeProduct.send(id) }
                , setCustomSize : (value) => {
                    const size = value.split(',');
                    const width = parseInt(size[0]);
                    const height = parseInt(size[1]);
                    if (width > 0 && height > 0) {
                        app.ports.setCustomSize.send([ width, height ]);
                    } else {
                        app.ports.setCustomSize.send([ window.innerWidth, window.innerHeight ]);
                    }
                }
                , savePng : () =>
                    { app.ports.savePng.send(null); }
                , saveBatch : sizes_ => {
                    let sizes = sizes_.concat([[0, 0]]);
                    let sizeIndex = 0;
                    savingBatch = true;
                    const nextPng = () => {
                        if (sizeIndex < sizes.length) {
                            const [ width, height ] = sizes[sizeIndex];
                            // console.log('sending', width, height);
                            app.ports.setCustomSize.send([ width, height ]);
                            sizeIndex = sizeIndex + 1;
                            setTimeout(nextPng, batchPause);
                        } else {
                            savingBatch = false;
                            // console.log('done saving batch');
                        }
                    };

                    nextPng();
                }
                , changeAmplitude : index => (x, y, z) =>
                    { app.ports.changeAmplitude.send({ layer: index, value: [ x, y, z ]}); }
                , shiftColor : index => (h, s, b) =>
                    { app.ports.shiftColor.send({ layer: index, value: [ h, s, b ]}); }
                , changeOpacity : index => value =>
                    { app.ports.changeOpacity.send({ layer: index, value: value }) }
                , turnOn : index =>
                    { app.ports.turnOn.send(index); }
                , turnOff : index =>
                    { app.ports.turnOff.send(index); }
                , mirrorOn : index =>
                    { app.ports.mirrorOn.send(index); }
                , mirrorOff : index =>
                    { app.ports.mirrorOff.send(index); }
                , rotate : value =>
                    { app.ports.rotate.send(value); }
                , applyRandomizer : value =>
                    { app.ports.applyRandomizer.send(prepareModelForImport(value)); }
                , refreshFluid : (index) =>
                    { app.ports.refreshFluid.send({ layer: index }); }
                , changeVariety : index => value =>
                    { app.ports.changeVariety.send({ layer: index, value }); }
                , changeOrbit : index => value =>
                    { app.ports.changeOrbit.send({ layer: index, value }); }
                , rebuildFluidGradients : (index) =>
                    { app.ports.requestRegenerateFluidGradients.send({ layer: index }); }
                , resize: (presetCode) =>
                    { app.ports.resize.send({
                        presetCode, viewport: [ window.innerWidth, window.innerHeight ]
                      });
                    }
                });

            // app.ports.pushUpdate.subscribe((data) => {
            //     // console.log('push update received', data);
            //     config.product = data.product;
            //     // TODO: apply the mode change in GUI and so change the size selection
            //     update();
            // });

        }

        model.layers.forEach((layer, index) => {
            if (is.fss(layer)) {
                // console.log('rebuild FSS layer', index);
                const fssScene = buildFSS(model, layer.model);
                fssScenes[index] = fssScene;
                app.ports.rebuildFss.send({ value: fssScene, layer: index });
            }
            if (is.nativeMetaballs(layer)) {
                const nativeMetaballsModel = nativeMetaballs.build(model.size, layer.model.colors);
                allNativeMetaballs[index] = nativeMetaballsModel;
                const debouncedResize = timing.debounce(function(newSize) {
                    const prev = allNativeMetaballs[index];
                    allNativeMetaballs[index] = nativeMetaballs.update(newSize, prev.colors, prev.metaballs);
                }, 300);
                app.ports.requestWindowResize.subscribe((size) => {
                    debouncedResize(size);
                });
                // app.ports.rebuildFss.send({ value: fssScene, layer: index });
            }
            // if (is.fluid(layer)) {
            //     const gradients = buildGradients(model, layer.model);
            //     app.ports.loadFluidGradients.send({ value: gradients, layer: index });
            // }
        });

        app.ports.requestFssRebuild.subscribe(({ layer : index, model, value : fssModel }) => {
            const layer = model.layers[index];
            //console.log(model.layers);
            //console.log('requestFssRebuild', index, model.layers[index], is.fss(layer));
            if (is.fss(layer)) {
                // console.log('forced to rebuild FSS layer', index);
                // FIXME: just use layer.model instead of `fssModel`
                const fssScene = buildFSS(model, fssModel);
                fssScenes[index] = fssScene;
                app.ports.rebuildFss.send({ value: fssScene, layer: index });
                layer.scene = fssScene;
            }
        });
    });

    app.ports.buildFluidGradientTextures.subscribe(([ index, layerModel ]) => {
        //if (is.fluid(layer)) {
            const gradients = buildGradients(layerModel);
            app.ports.loadFluidGradientTextures.send({ value: gradients, layer: index });
        //}
    });

    app.ports.updateNativeMetaballs.subscribe(([ index, colors ]) => {
        const prev = allNativeMetaballs[index];
        allNativeMetaballs[index] = nativeMetaballs.update(prev.size, colors, prev.metaballs);
    });

    app.ports.bang.send(null);

    let panelsHidden = false;

    document.addEventListener('keydown', (event) => {
        if (event.keyCode == 32) {
            const overlayPanels = document.querySelectorAll('.hide-on-space');
            for (let i = 0; i < overlayPanels.length; i++) {
                overlayPanels[i].style.display = panelsHidden ? 'block' : 'none';
            }
            panelsHidden = !panelsHidden;
        }
    });

}, 100);


