package pkg{
import flash.events.Event;
import flash.utils.ByteArray;

public class DataEvent extends Event {
    public static const OK:String = 'OK';
    public static const ERROR:String = 'ERROR';

    public var data:ByteArray;

    public function DataEvent(type:String, data:ByteArray = null) {
        super(type);
        this.data = data;
    }
}
}

