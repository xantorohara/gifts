package {
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.PixelSnapping;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.MouseEvent;
import flash.events.StatusEvent;
import flash.events.TimerEvent;
import flash.media.Camera;
import flash.media.Video;
import flash.system.Security;
import flash.utils.ByteArray;
import flash.utils.Timer;

import mx.containers.Canvas;
import mx.controls.Alert;
import mx.controls.Text;
import mx.core.UIComponent;

import org.libspark.flartoolkit.core.FLARCode;
import org.libspark.flartoolkit.core.param.FLARParam;
import org.libspark.flartoolkit.core.raster.rgb.FLARRgbRaster_BitmapData;
import org.libspark.flartoolkit.core.transmat.FLARTransMatResult;
import org.libspark.flartoolkit.detector.FLARSingleMarkerDetector;
import org.libspark.flartoolkit.support.pv3d.FLARBaseNode;
import org.libspark.flartoolkit.support.pv3d.FLARCamera3D;
import org.papervision3d.cameras.Camera3D;
import org.papervision3d.core.geom.renderables.Vertex3D;
import org.papervision3d.core.proto.MaterialObject3D;
import org.papervision3d.events.FileLoadEvent;
import org.papervision3d.lights.PointLight3D;
import org.papervision3d.materials.BitmapFileMaterial;
import org.papervision3d.materials.BitmapMaterial;
import org.papervision3d.materials.shaders.PhongShader;
import org.papervision3d.materials.shaders.ShadedMaterial;
import org.papervision3d.objects.DisplayObject3D;
import org.papervision3d.render.LazyRenderEngine;
import org.papervision3d.scenes.Scene3D;
import org.papervision3d.view.Viewport3D;

import pkg.MyDAE;

public class MyScenePanel extends Canvas {

    [Embed(source="resources/flar/patterns/marker8.pat", mimeType="application/octet-stream")]
    private var pattern:Class;

    [Embed(source="resources/flar/camera_para.dat", mimeType="application/octet-stream")]
    private var params:Class;
    private var msg:Text = new Text();
    private const WIDTH:Number = 640;
    private var HEIGHT:Number = 480;

    private var param:FLARParam = new FLARParam();
    protected var code:FLARCode = new FLARCode(8, 8);
    protected var raster:FLARRgbRaster_BitmapData = new FLARRgbRaster_BitmapData(WIDTH, HEIGHT);
    protected var resultMat:FLARTransMatResult = new FLARTransMatResult();
    protected var renderer:LazyRenderEngine;
    protected var detector:FLARSingleMarkerDetector;
    protected var capture:Bitmap;
    protected var base:Sprite;
    protected var viewport:Viewport3D;
    protected var scene:Scene3D = new Scene3D();
    protected var video:Video = new Video(WIDTH, HEIGHT);
    protected var webcam:Camera;

    private var model:MyDAE = new MyDAE();

    protected var markerNode:FLARBaseNode;
    private static var MARKER_REMOVED_DELAY:int = 50;

    private var modelLoaded:Boolean = false;
    private var markerRemoveCounter:int = MARKER_REMOVED_DELAY;
    protected var camera3d:Camera3D;

    public var photo:String;
    private var _modelName:String;

    private var isVisible:Boolean = false;

    private var firstCameraInit:Boolean = true;

    private var detectorTimer:Timer = new Timer(150);

    [Bindable]
    public var showLight:Boolean = false;

    [Bindable]
    public var resizeModel:Boolean = true;

    [Bindable]
    public var cameraView:Boolean = false;

    private var pointLight3D:PointLight3D;

    private var detected:Boolean = false;

    public function set modelName(value:String):void {
        trace('change model: ' + value);

        if (value) {
            _modelName = value;
        }

        if (isVisible) {
            loadModel();
        }
    }

    public function show():void {
        isVisible = true;
        msg.alpha = 0.3;
        loadModel();
        initCamera();
        addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    private function loadModel():void {
        modelLoaded = false;
        markerNode.visible = false;
        model.visible = false;
        if (_modelName) {
            model.loadModel('lib/models', _modelName);
        }
    }

    public function hide():void {
        isVisible = false;
        trace('hide');
        if (video) {
            video.attachCamera(null);
        }
        removeEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    public function MyScenePanel() {
        super();

        var viewPanel:UIComponent = new UIComponent();
        viewPanel.width = WIDTH;
        viewPanel.height = HEIGHT;
        viewPanel.x = 0;
        viewPanel.y = 0;

        param.loadARParam(new params() as ByteArray);
        param.changeScreenSize(WIDTH, HEIGHT);

        code.loadARPatt(new pattern());

        capture = new Bitmap(BitmapData(raster.getBuffer()), PixelSnapping.AUTO);//, true
        detector = new FLARSingleMarkerDetector(param, code, 80);
        detector.setContinueMode(true);

        base = viewPanel.addChild(new Sprite()) as Sprite;
        base.scaleX = -1;
        base.x = WIDTH;

        capture.width = WIDTH;
        capture.height = HEIGHT;
        base.addChild(capture);

        viewport = base.addChild(new Viewport3D(320, 240)) as Viewport3D;
        viewport.scaleX = 2;
        viewport.scaleY = 2;
        viewport.x = -4;

        markerNode = scene.addChild(new FLARBaseNode()) as FLARBaseNode;
        model.scale = 1;
        model.rotationX = 0;
        model.play("all", true);
        model.addEventListener(FileLoadEvent.LOAD_COMPLETE, onLoadGiftModel);
        model.addEventListener(IOErrorEvent.IO_ERROR, function(evt:IOErrorEvent):void {
            Alert.show("Ошибка при загрузке модели: " + evt.text);
        });


        markerNode.addChild(model);

        detectorTimer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent):void {
            if (isVisible && cameraView) {
                try {
                    detected = detector.detectMarkerLite(raster, 80) && detector.getConfidence() > 0.5;
                } catch (e:Error) {
                    trace('detector:' + e.message)
                }
            }
        });
        detectorTimer.start();

        addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent):void {
            if (camera3d) {
                camera3d.z += e.delta * 2;
            }
        });

        webcam = Camera.getCamera();
        if (webcam) {
            webcam.addEventListener(StatusEvent.STATUS, cameraStatusHandler);
            webcam.setMode(WIDTH, HEIGHT, 25);
            if (webcam.muted) {
                Security.showSettings("privacy");
            } else {
                cameraView = true;
            }
        }

        pointLight3D = new PointLight3D();
        pointLight3D.x = 100;
        pointLight3D.y = 100;
        pointLight3D.z = -100;
        pointLight3D.showLight = false;
        scene.addChild(pointLight3D);

        msg.width = 600;
        msg.setStyle("textAlign", "center");
        msg.setStyle("horizontalCenter", 0);
        msg.setStyle("fontSize", 16);
        msg.y = 10;
        msg.selectable = false;

        msg.addEventListener(MouseEvent.ROLL_OVER, function (event:MouseEvent):void {
            event.target.alpha = 0.9;
        });

        msg.addEventListener(MouseEvent.ROLL_OUT, function (event:MouseEvent):void {
            event.target.alpha = 0.3;
        });

        addChild(viewPanel);

        addChild(msg);
    }


    private function onEnterFrame(e:Event = null):void {
        if (cameraView) {
            capture.bitmapData.draw(video);

            if (modelLoaded) {
                if (detected) {
                    markerRemoveCounter = MARKER_REMOVED_DELAY;
                    detector.getTransformMatrix(resultMat);
                    markerNode.setTransformMatrix(resultMat);
                    markerNode.visible = true;
                } else {
                    if (markerRemoveCounter <= 0 && markerNode.visible) {
                        markerNode.visible = false;
                    } else {
                        markerRemoveCounter--;
                    }
                }
            }
        } else {
            markerNode.rotationY = viewport.containerSprite.mouseX * 0.6;
            markerNode.rotationX = viewport.containerSprite.mouseY * 0.1 - 10;

            markerNode.y = (viewport.containerSprite.mouseY - (viewport.containerSprite.height / 2)) / 5;
        }
        renderer.render();
    }

    private function onLoadGiftModel(e:Event):void {
        var photo_mat_1:BitmapFileMaterial = new BitmapFileMaterial();
        photo_mat_1.checkPolicyFile = true;
        photo_mat_1.texture = photo;
        photo_mat_1.smooth = true;
        model.replaceMaterialByName(photo_mat_1, "receiver_avatar_mat");

        modelLoaded = true;
        markerNode.visible = !cameraView;
        model.visible = true;

        if (showLight) {
            replaceDaeMaterialsByShaders(model);
        }

        resizeModel2();

        if (!cameraView) {
            camera3d.z = -200;
        }
    }

    private function resizeModel2():void {
        if (!model) {
            return;
        }
        if (resizeModel && !cameraView) {
            var modelScale:Number = 150 / getDaeMaxDimension(model);
            if (modelScale > 1) {
                modelScale = 1;
            }
            model.scale = modelScale;
        } else {
            model.scale = 1;
        }
    }

    private function replaceDaeMaterialsByShaders(sourceModel:DisplayObject3D):void {
        for (var mname:String in sourceModel.materials.materialsByName) {
            var material:MaterialObject3D = sourceModel.materials.getMaterialByName(mname);
            if (material.bitmap) {
                var bmaterial:BitmapMaterial = new BitmapMaterial(material.bitmap, true);
                var shader:PhongShader = new PhongShader(pointLight3D, 0xffffff, getAverageBitmapColor(material.bitmap), 10);
                //var shader:PhongShader = new PhongShader(pointLight3D, 0xffffff, 0xCCCCCC, 10);
                material = new ShadedMaterial(bmaterial, shader);
                sourceModel.replaceMaterialByName(material, mname);
            } else {
                trace('material ' + mname + ' has no bitmap');
            }
        }
        for (var childName:String in sourceModel.childrenList()) {
            replaceDaeMaterialsByShaders(sourceModel.getChildByName(childName));
        }
    }

    private function getDaeMaxDimension(sourceModel:DisplayObject3D):Number {
        var dimensions:Object = getDaeDimension(sourceModel);
        var result:Number = 0;
        result = Math.max(dimensions.maxX - dimensions.minX, result);
        result = Math.max(dimensions.maxY - dimensions.minY, result);
        result = Math.max(dimensions.maxZ - dimensions.minZ, result);
        return result;
    }

    private function getDaeDimension(sourceModel:DisplayObject3D):Object {
        var result:Object = {minX:0, maxX: 0, minY: 0, maxY: 0, minZ: 0, maxZ: 0};

        if (sourceModel.children) {
            for each(var child:DisplayObject3D in sourceModel.children) {
                var childResult:Object = getDaeDimension(child);
                result.minX = Math.min(childResult.minX, result.minX);
                result.minY = Math.min(childResult.minY, result.minY);
                result.minZ = Math.min(childResult.minZ, result.minZ);

                result.maxX = Math.max(childResult.maxX, result.maxX);
                result.maxY = Math.max(childResult.maxY, result.maxY);
                result.maxZ = Math.max(childResult.maxZ, result.maxZ);
            }

            if (sourceModel.geometry) {
                for each(var vertex:Vertex3D in sourceModel.geometry.vertices) {
                    result.maxX = Math.max(result.maxX, vertex.x);
                    result.maxY = Math.max(result.maxY, vertex.y);
                    result.maxZ = Math.max(result.maxZ, vertex.z);

                    result.minX = Math.min(result.minX, vertex.x);
                    result.minY = Math.min(result.minY, vertex.y);
                    result.minZ = Math.min(result.minZ, vertex.z);
                }
            }
        }

        return result;
    }

    private function getAverageBitmapColor(source:BitmapData):uint {
        var red:Number = 0;
        var green:Number = 0;
        var blue:Number = 0;
        var count:Number = 0;
        var pixel:Number;
        for (var x:int = 0; x < source.width; x++) {
            for (var y:int = 0; y < source.height; y++) {
                pixel = source.getPixel(x, y);
                red += pixel >> 16 & 0xFF;
                green += pixel >> 8 & 0xFF;
                blue += pixel & 0xFF;
                count++
            }
        }
        red /= count;
        green /= count;
        blue /= count;
        return red << 16 | green << 8 | blue;
    }

    private function cameraStatusHandler(event:StatusEvent):void {
        trace(event.code);
        if (event.code == 'Camera.Unmuted') {
            cameraView = true;
        } else if (event.code == 'Camera.Muted') {
            cameraView = false;
        }
        initCamera();
    }

    public function switchViewMode():void {
        cameraView = !cameraView;
        resizeModel2();

        initCamera();
    }

    public function initCamera():void {
        if (cameraView) {
            initRealCamera();
        } else {
            initVirtualCamera();
        }
        renderer = new LazyRenderEngine(scene, camera3d, viewport);
    }

    public function initRealCamera():void {
        trace('init camera');
        if (!webcam) {
            cameraView = false;
            initVirtualCamera();
            return;
        }

        if (webcam.muted && firstCameraInit) {
            firstCameraInit = false;
            Security.showSettings("privacy");
            return;
        }
        video.attachCamera(webcam);

        capture.visible = true;
        markerNode.visible = false;

        if (!(camera3d is FLARCamera3D)) {
            camera3d = new FLARCamera3D(param);
        }

        markerNode.x = 0;
        markerNode.y = 0;
        markerNode.z = 0;
        markerNode.rotationY = 0;
        markerNode.rotationX = 0;
        markerNode.rotationZ = 0;
        model.rotationX = 90;
        model.rotationY = 0;
        model.rotationZ = 0;
        model.y = 0;
    }

    public function initVirtualCamera():void {
        trace('init virtual camera');
        video.attachCamera(null);
        if (camera3d == null || (camera3d is FLARCamera3D)) {
            camera3d = new Camera3D();
            camera3d.z = -200;
            camera3d.x = 0;
            camera3d.y = 0;
            camera3d.zoom = 20;
        }

        capture.visible = false;
        markerNode.visible = true;
        markerNode.scale = 1;
        markerNode.x = 0;
        markerNode.y = 0;
        markerNode.z = 0;
        markerNode.rotationY = 0;
        markerNode.rotationX = 0;
        markerNode.rotationZ = 0;

        model.y = -60;
        model.rotationX = 0;
        model.rotationY = 90;
        model.rotationZ = 0;
    }
}
}