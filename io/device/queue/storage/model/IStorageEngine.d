module io.device.queue.storage.model.IStorageEngine;

private import tango.io.device.Conduit;

interface IStorageEngine
{
    public size_t write(void[] data);
    public void[] read(size_t amount);
    public void writeToConduit(Conduit);
    public void readFromConduit(Conduit);
    public size_t seek(size_t offset);
    public size_t size();
    public void init(size_t size);
};