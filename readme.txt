Pre-requisites: Visual Studio .NET on Windows.

Keep directory 'testwebserver' anywhere. This is the http webserver implementation.
Move directory 'server' to c: This is the web directory.
This should create a folder named c:\server with directories inside like c:\server\conf, c:\server\errorpages, c:\server\logs, c:\server\www.
The c:\server\www is where a web programmer puts his html and other stuff.

Ensure that port 8081 is not used by any other process. If it is, change the port in the sort code.
Open testwebserver.sln and run it. If you want in code set the variable loglevel to 3, this does logging to console and to c:\server\logs directory.
If Windows asks firewall to open port for this executable, choose 'Allow Access'.

Then in browser just hit:
http://localhost:8081 

and you should see directory contents.

I think there is a bug due to which if you click on directory contents, the page or file comes with reverse slash which  might not work correctly. So make sure to enter the url by hand using correct slash i.e. /