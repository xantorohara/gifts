package pkg{

import flash.errors.IOError;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.IOErrorEvent;
import flash.net.URLLoader;
import flash.net.URLLoaderDataFormat;
import flash.net.URLRequest;
import flash.utils.ByteArray;

public class ModelLoader extends EventDispatcher {

    private var loader:URLLoader = new URLLoader();

    public function ModelLoader() {
        loader.dataFormat = URLLoaderDataFormat.BINARY;
        loader.addEventListener(Event.COMPLETE, completeHandler);
        loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
    }

    private function completeHandler(event:Event):void {
        trace('model data loaded');
        var bytes:ByteArray = loader.data;
        try {
            bytes.uncompress();
            dispatchEvent(new DataEvent(DataEvent.OK, bytes));
        } catch (e:IOError) {
            dispatchEvent(new DataEvent(DataEvent.ERROR));
        }
    }

    private function ioErrorHandler(event:IOErrorEvent):void {
        dispatchEvent(new DataEvent(DataEvent.ERROR));
    }

    public function load(model:String):void {
        trace('loading model...' + model + '1');
        var request:URLRequest = new URLRequest(model + '1');
        try {
            loader.load(request);
        } catch (error:Error) {
            trace("Unable to load");
        }
    }
}
}