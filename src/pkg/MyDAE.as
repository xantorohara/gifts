package pkg {
import flash.errors.IOError;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.net.URLLoader;

import flash.net.URLLoaderDataFormat;

import flash.net.URLRequest;
import flash.utils.ByteArray;

import org.ascollada.io.DaeReader;
import org.papervision3d.materials.utils.MaterialsList;
import org.papervision3d.objects.parsers.DAE;

public class MyDAE extends DAE {
    private var loader:URLLoader = new URLLoader();

    public function MyDAE() {
        super(true, "model", true);
        loader.dataFormat = URLLoaderDataFormat.BINARY;
        loader.addEventListener(Event.COMPLETE, completeHandler);
        loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
    }

    private function completeHandler(event:Event):void {
        trace('model loaded');
        var bytes:ByteArray = loader.data;
        try {
            bytes.uncompress();
            loadBytes(bytes);
        } catch (e:IOError) {
            trace('model failed');
        }
    }

    private function ioErrorHandler(event:IOErrorEvent):void {
        trace('model ioerror');
    }

    public function loadModel(path:String, model:String):void {
        materials = new MaterialsList();
        _fileSearchPaths = [path + '/' + model];

        trace('loading model...' + path + '/' + model);
        var request:URLRequest = new URLRequest(path + '/' + model + '/' + model + '.3do?'+new Date().time);
        try {
            loader.load(request);
        } catch (error:Error) {
            trace("Unable to load");
        }
    }

    private function loadBytes(bytes:ByteArray):void {
        buildFileInfo(bytes);

        this.parser = new DaeReader(false);
        this.parser.addEventListener(Event.COMPLETE, onParseComplete);
        this.parser.addEventListener(ProgressEvent.PROGRESS, onParseProgress);
        this.parser.addEventListener(IOErrorEvent.IO_ERROR, onParseError);

        this.COLLADA = new XML(bytes);
        this.parser.loadDocument(bytes, _fileSearchPaths);
    }
}
}