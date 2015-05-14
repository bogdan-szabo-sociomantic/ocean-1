/*******************************************************************************

    Copyright:      Copyright (c) 2015 sociomantic labs. All rights reserved

    Test-suite for UnixSockets.

    The tests involve unix sockets and forking
    processes, so are placed in this slowtest module.

    FLAKY: the unittests in this module are very flaky, as they rely on making
    various system calls (fork(), waitpid(), epoll_wait(), epoll_ctl(), etc)
    which could, under certain environmental conditions, fail.

*******************************************************************************/

module test.unixsocket.main;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Exception;
import ocean.core.Test;
import ocean.sys.socket.UnixSocket;
import tango.text.convert.Format;

import tango.stdc.posix.sys.socket;
import tango.stdc.posix.sys.wait;
import tango.stdc.posix.unistd;
import tango.stdc.posix.stdlib : mkdtemp;
import tango.stdc.stdio;
import tango.math.Math;
import tango.net.device.LocalSocket;
import tango.stdc.string;
import tango.sys.Process;

import ocean.text.util.StringC;

const char[] CLIENT_STRING = "Hello from the client";

const char[] SERVER_STRING = "Hello from the server";

int runClient ( LocalAddress socket_address )
{
    auto client = new UnixSocket();

    scope (exit) client.close();

    auto socket_fd = client.socket();

    enforce(socket_fd >= 0, "socket() call failed!");

    auto connect_result = client.connect(socket_address);

    enforce(connect_result == 0,
            "connect() call failed!");

    // send some data
    client.write(CLIENT_STRING);

    auto read_buffer = new char[max(SERVER_STRING.length,
                                    CLIENT_STRING.length) + 1];
    read_buffer[] = 0;

    auto buff = cast(void[])read_buffer;

    // receive some data
    auto read_bytes = client.recv(buff, 0);

    enforce(read_bytes > 0);

    read_buffer.length = read_bytes;

    test(read_buffer == SERVER_STRING);

    return 0;
}

int main ( )
{
    auto path = mkdtemp("/tmp/Dunittest-XXXXXX\0".dup.ptr);
    enforce(path !is null);

    auto test_dir = StringC.toDString(path);

    auto socket_path = test_dir ~ "/socket";

    scope (exit)
    {
        char[] rm_cmd;
        Format.format(rm_cmd, "rm -rf {}", path);

        auto proc = new Process(rm_cmd, null);
        proc.execute();
        proc.wait();
    }

    auto socket_address = new LocalAddress(socket_path);

    auto server = new UnixSocket();

    // close the socket
    scope (exit) server.close();

    auto socket_fd = server.socket();

    enforce(socket_fd >= 0, "socket() call failed!");

    auto bind_result = server.bind(socket_address);
    enforce(bind_result == 0, "bind() call failed!");

    int backlog = 10;

    auto listen_result = server.listen(backlog);
    enforce(listen_result == 0, "listen() call failed!");

    pid_t pid = fork();

    enforce(pid != -1);

    if (pid == 0)  // client
    {
        return runClient(socket_address);
    }

    int connection_fd;

    auto peer_socket = new UnixSocket();

    scope (exit) peer_socket.close();

    if (peer_socket.accept(server) != -1)
    {
        connection_handler(peer_socket);
    }

    int status;

    waitpid(pid, &status, 0);

    enforce(status == 0, "Child exit status should be 0");

    return 0;
}

void connection_handler ( UnixSocket peer_socket )
{
    auto read_buffer = new char[max(SERVER_STRING.length,
                                    CLIENT_STRING.length) + 1];
    read_buffer[] = '\0';

    auto buff = cast(void[])read_buffer;

    auto read_bytes = peer_socket.recv(buff, 0);

    enforce(read_bytes > 1);

    read_buffer.length = read_bytes;

    enforce(read_buffer == CLIENT_STRING,
        "Expected: " ~ CLIENT_STRING ~ " Got: " ~ read_buffer);

    // send the response
    peer_socket.write(SERVER_STRING);
}
