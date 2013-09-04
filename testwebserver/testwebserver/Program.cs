using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Text.RegularExpressions;
using System.Collections.Generic;

namespace MyServer
{
    struct Deny
    {
        public string url;
        public string ip;
    }

    class Program
    {
        static TcpListener server;
        static string serverstring = "TestServer/1.00";

        static string serverroot = @"c:\server";
        static string wwwroot = serverroot + @"/www";
        static string logroot = serverroot + @"/logs";
        static string confroot = serverroot + @"/conf";
        static string errorpagesroot = serverroot + @"/errorpages";

        static string listenaddress = "0.0.0.0";
        static int port = 8081;
        static string host = "myserver";

        static string[] defaults = { "index.php", "index.html" };
        static string cgidir = "/cgi-bin";
        static string phpbin = "c:\\php5\\php-cgi.exe";

        static StreamWriter log;
        static int loglevel = 0;

        static void SetEnv(string variable, string value)
        {
            Environment.SetEnvironmentVariable(variable, value);
        }

        static void WriteLog(int level, int levelExpected, string mesg)
        {
            if (level >= levelExpected)
            {
                Console.WriteLine(mesg);
                log.WriteLine(mesg);
            }
        }

        static string GetErrorPage(int code)
        {
            try
            {
                return File.ReadAllText(String.Format("{0}/{1}.html", errorpagesroot, code));
            }
            catch (FileNotFoundException)
            {
                return "Error page not found.";
            }
            catch (Exception)
            {
                return "Invalid error page.";
            }
        }

        static List<Deny> GetDenied()
        {
            try
            {
                var tmp = new List<Deny>();
                var r = File.ReadAllLines(confroot + "/deny.txt");

                foreach (var line in r)
                {
                    if (line.Contains(" "))
                    {
                        tmp.Add(new Deny { url = line.Split(' ')[0], ip = line.Split(' ')[1] });
                    }
                    else
                    {
                        tmp.Add(new Deny { url = line.Split(' ')[0], ip = ".*" });
                    }
                }

                return tmp;
            }
            catch (Exception e)
            {
                //Console.WriteLine(e);
                return new List<Deny>();
            }
        }

        static string GetExt(string path2)
        {
            string ext = String.Empty;

            try
            {
                if (path2.Contains("."))
                {
                    var s = path2.Split('.');
                    ext = s[s.Length - 1];
                }
            }
            catch { }

            return ext;
        }

        static string Rewrite(string url, string rule, string rule2)
        {
            return Regex.Replace(url, rule, rule2);
        }

        static void HTTPToCGI(string req, string http, string cgi)
        {
            var reg = Regex.Match(req.Substring(0, req.IndexOf("\r\n\r\n")) + "\r\n\r\n", String.Format("{0}:\\ (.+?)\r\n", http));
            
            if (reg.Success)
            {
                SetEnv(cgi, reg.Groups[1].Value);
            }
            else
            {
                SetEnv(cgi, "");
            }
        }

        static Process PrepareCGI(string method, string path, string req, TcpClient client)
        {
            var script = String.Empty;
            var query = String.Empty;

            if (path.Contains("?"))
            {
                script = path.Split('?')[0];
                query = path.Split('?')[1];
            }
            else
            {
                script = path;
            }

            SetEnv("GATEWAY_INTERFACE", "CGI/1.1");

            SetEnv("SERVER_NAME", host);
            SetEnv("SERVER_PORT", port.ToString());
            SetEnv("SERVER_SOFTWARE", serverstring);

            SetEnv("REMOTE_ADDR", client.Client.RemoteEndPoint.ToString().Split(':')[0]);
            SetEnv("REQUEST_METHOD", method);
            SetEnv("SCRIPT_NAME", script.Replace(wwwroot, ""));
            SetEnv("QUERY_STRING", query);

            HTTPToCGI(req, "User-Agent", "HTTP_USER_AGENT");
            HTTPToCGI(req, "Cookie", "HTTP_COOKIE");
            HTTPToCGI(req, "Referer", "HTTP_REFERER");
            HTTPToCGI(req, "Content-Type", "CONTENT_TYPE");
            HTTPToCGI(req, "Content-Length", "CONTENT_LENGTH");

            ProcessStartInfo pi;

            if (script.EndsWith(".php"))
            {
                SetEnv("REDIRECT_STATUS", "200");
                SetEnv("SCRIPT_FILENAME", script);
                pi = new ProcessStartInfo("cmd", String.Format("/c {0} {1}", phpbin, script));
            }
            else
            {
                string postdata = req.Substring(req.IndexOf("\r\n\r\n") + 4);
                string[] alldata = postdata.Split('&');
                string paramstring = string.Empty;
                foreach (string s in alldata)
                {
                    paramstring += " " + s;                
                }

                if (!String.IsNullOrEmpty(postdata))
                {
                    pi = new ProcessStartInfo("powershell", "/c " + script + paramstring);
                }
                else
                {
                    pi = new ProcessStartInfo("powershell", "/c " + script);
                }
            }

            pi.RedirectStandardOutput = true;
            if (method == "POST") pi.RedirectStandardInput = true;
            pi.UseShellExecute = false;

            var p = new Process();
            p.StartInfo = pi;

            return p;
        }

        static Dictionary<string, string> GetMime()
        {
            var tmp = new Dictionary<string, string>();

            try
            {
                var read = File.ReadAllText(confroot + "/mime.txt").Replace(" ", "").Trim("\r\n".ToCharArray()).Split('\n');

                foreach (var i in read)
                {
                    if (i.Length > 2) tmp.Add(i.Split(':')[0], i.Split(':')[1]);
                }
            }
            catch (Exception e)
            {
                Console.WriteLine(e);
            }

            return tmp;
        }

        private static string StartRewrite(string path1)
        {
            var rewrite = File.ReadAllLines(confroot + "/rewrite.txt");

            foreach (string line in rewrite)
            {
                try
                {
                    path1 = Rewrite(path1, line.Split(' ')[0], line.Split(' ')[1]);
                }
                catch
                {
                    WriteLog(loglevel, 1, String.Format("{0} - ERROR IN FILTER: \"{1}\"", DateTime.Now, line));                    
                }
            }
            return path1;
        }

        private static void ProcessVerbNotImplemented(StreamWriter w)
        {
            try
            {
                w.Write("HTTP/1.1 501 Not Implemented\r\n");
                w.Write("Server: {0}\r\n", serverstring);
                w.Write("\r\n");
                w.Flush();
            }
            catch
            {
            }
        }

        private static void ProcessBadRequest(StreamWriter w, string req)
        {
            try
            {
                w.Write("HTTP/1.1 400 Bad Request\r\n");
                w.Write("Server: {0}\r\n", serverstring);
                w.Write("\r\n");
                w.Flush();
            }
            catch
            {
            }
            Console.WriteLine(req);
        }

        private static void ProcessNotFound(StreamWriter w, string verbheader, string path1)
        {
            try
            {
                w.Write("HTTP/1.1 404 Not Found\r\n");
                w.Write("Server: {0}\r\n", serverstring);
                w.Write("Content-Type: text/html\r\n");
                w.Write("\r\n");
                if (!verbheader.StartsWith("HEAD "))
                {
                    w.Write(String.Format(GetErrorPage(404), path1, serverstring));
                }
                w.Flush();
            }
            catch
            {
            }
        }

        private static void ProcessForbidden(StreamWriter w, string verbheader, string path1, string serverstring)
        {
            try
            {
                w.Write("HTTP/1.1 403 Forbidden\r\n");
                w.Write("Server: {0}\r\n", serverstring);
                w.Write("Content-Type: text/html\r\n");
                w.Write("\r\n");
                if (!verbheader.StartsWith("HEAD "))
                {
                    w.Write(String.Format(GetErrorPage(403), path1, serverstring));
                }
                w.Flush();
            }
            catch
            {
            }
        }

        private static void ProcessPOST(TcpClient c, NetworkStream ns, StreamWriter w, string req, string path2)
        {
            if (File.Exists(path2.Contains("?") ? path2.Remove(path2.IndexOf("?")) : path2))
            {
                var p = PrepareCGI("POST", path2, req, c);
                p.Start();

                var postdata = req.Substring(req.IndexOf("\r\n\r\n") + 4);

                p.StandardInput.Write(postdata);
                p.StandardInput.Close();

                w.Write("HTTP/1.1 200 OK\r\n");
                w.Write("Server: {0}\r\n", serverstring);
                w.Flush();

                List<byte> outputbytes = new List<byte>();

                outputbytes.Add((byte)Convert.ToInt32('\r'));
                outputbytes.Add((byte)Convert.ToInt32('\n'));
                while (!p.StandardOutput.EndOfStream)
                {
                    int i = p.StandardOutput.Read();
                    outputbytes.Add((byte)i);
                }
                w.Write("Content-Length: {0}\r\n", (outputbytes.Count-2));
                w.Flush();
                for (int i = 0; i < outputbytes.Count; i++)
                {
                    ns.WriteByte(outputbytes[i]);
                    ns.Flush();
                }
            }
            else
            {
                throw new NotFoundException();
            }
        }

        private static void ProcessGET(TcpClient c, NetworkStream ns, StreamWriter w, string req, string[] reqline, ref string path1, ref string path2)
        {
            var isfile = false;

            if (Directory.Exists(path2))
            {
                foreach (string def in defaults)
                {
                    if (File.Exists(path2 + def))
                    {
                        path1 += def;
                        path2 += def;

                        isfile = true;
                        break;
                    }
                }
            }
            else
            {
                isfile = true;
            }

            if (!isfile)
            {
                ProcessGenerateList(ns, w, reqline, path1, path2);
            }
            else
            {
                // file
                if (path1.StartsWith(cgidir) || ((path1.Contains("?") ? path1.Remove(path1.IndexOf("?")) : path2).EndsWith(".php")))
                {
                    ProcessCgiGET(c, ns, w, req, reqline, path2);
                }
                else
                {
                    ProcessFileGET(ns, w, req, reqline, path2);
                }
            }
        }

        private static void ProcessFileGET(NetworkStream ns, StreamWriter w, string req, string[] reqline, string path2)
        {
            if (!File.Exists(path2))
            {
                throw new NotFoundException();
            }

            var ext = GetExt(path2);
            var mime = GetMime();


            using (var file = File.Open(path2, FileMode.Open, FileAccess.Read, FileShare.Read))
            {             
                w.Write("HTTP/1.1 200 OK\r\n");
                w.Write("Server: {0}\r\n", serverstring);
                w.Write("Accept-Range: bytes\r\n");
                int length = 0;
                if (!reqline[0].StartsWith("Head"))
                {
                    //TBD - need to just calculate total buffer size
                    var file1 = File.Open(path2, FileMode.Open, FileAccess.Read, FileShare.Read);
                    while (file1.Position < file1.Length)
                    {
                        byte[] buffer = new byte[1024];
                        file1.Read(buffer, 0, 1024);
                        length += 1024;
                    }
                    w.Write("Content-Length: {0}\r\n", length);
                }
                else
                {
                    w.Write("Content-Length: {0}\r\n", file.Length);
                }
                if (mime.ContainsKey(ext))
                {
                    w.Write("Content-Type: {0}\r\n", mime[ext]);
                }
                w.Write("\r\n");
                w.Flush();

                if (!reqline[0].StartsWith("HEAD "))
                {
                    while (file.Position < file.Length)
                    {
                        byte[] buffer = new byte[1024];

                        file.Read(buffer, 0, 1024);
                        ns.Write(buffer, 0, 1024);

                        ns.Flush();
                    }
                }
            }
        }

        private static void ProcessCgiGET(TcpClient c, NetworkStream ns, StreamWriter w, string req, string[] reqline, string path2)
        {
            if (File.Exists(path2.Contains("?") ? path2.Remove(path2.IndexOf("?")) : path2))
            {
                var p = PrepareCGI("GET", path2, req, c);
                p.Start();

                w.Write("HTTP/1.1 200 OK\r\n");
                w.Write("Server: {0}\r\n", serverstring);
                w.Flush();

                if (!reqline[0].StartsWith("HEAD "))
                {
                    while (!p.StandardOutput.EndOfStream)
                    {
                        ns.WriteByte((byte)p.StandardOutput.Read());
                        ns.Flush();
                    }
                }
            }
            else
            {
                throw new NotFoundException();
            }
        }

        private static void ProcessGenerateList(NetworkStream ns, StreamWriter w, string[] reqline, string path1, string path2)
        {
            var list = new StringBuilder();
            var listpath = path1.Last() == '/' ? path1.Substring(0, path1.Length - 1) : path1;

            list.AppendLine("<title>Directory listing for " + listpath + "</title>");
            list.AppendLine("<h1>Directory listing for " + listpath + "</h1>");

            list.AppendLine(String.Format("<a href=\"{0}\">{1}</a><br>", listpath, "./"));
            list.AppendLine(String.Format("<a href=\"{0}\">{1}</a><br>", ".", "../"));

            foreach (string i in Directory.GetDirectories(path2))
            {
                list.AppendLine(String.Format("<a href=\"{0}\">{1}/</a><br>",
                    i.Replace(wwwroot, ""),//.Replace("\\", "/"),
                    i.Replace(wwwroot + path1, "")//.Replace("\\", "")
                    ));
            }

            foreach (string i in Directory.GetFiles(path2))
            {
                list.AppendLine(String.Format("<a href=\"{0}\">{1}</a><br>",
                    i.Replace(wwwroot, ""),//.Replace("\\", "/"),
                    i.Replace(wwwroot + path1, "")//.Replace("\\", "")
                    ));
            }

            w.Write("HTTP/1.1 200 OK\r\n");
            w.Write("Content-Type: text/html\r\n");
            w.Write("Server: {0}\r\n", serverstring);
            w.Write("Content-Length: {0}\r\n", list.Length);
            w.Write("\r\n");
            w.Flush();

            if (!reqline[0].StartsWith("HEAD "))
            {
                foreach (char i in list.ToString())
                {
                    ns.WriteByte((byte)i);
                    ns.Flush();
                }
            }
        }

        static void HandleRequest(TcpClient c)
        {
            WriteLog(loglevel, 3, String.Format("{0} - {1} connected.", DateTime.Now, c.Client.RemoteEndPoint));

            using (var ns = c.GetStream())
            {
                using (var r = new StreamReader(ns))
                {
                    using (var w = new StreamWriter(ns))
                    {
                        var reqbuild = new StringBuilder();

                        while (!ns.DataAvailable) ;

                        while (ns.DataAvailable)
                        {
                            reqbuild.Append((char)ns.ReadByte());
                        }

                        var req = reqbuild.ToString();
                        string[] reqline = new string[] { };
                        string path1 = String.Empty;

                        try
                        {
                            try
                            {
                                reqline = req.Split('\n');
                                path1 = reqline[0].Split(' ')[1];
                            }
                            catch
                            {
                                throw new BadRequestException();
                            }

                            foreach (var denied in GetDenied())
                            {
                                if (new Regex(denied.url).IsMatch(path1) && new Regex(denied.ip).IsMatch(c.Client.RemoteEndPoint.ToString().Split(':')[0]))
                                {
                                    throw new ForbiddenException();
                                }
                            }

                            path1 = StartRewrite(path1);

                            if (path1.StartsWith("..") || path1.StartsWith("/.."))
                            {
                                throw new ForbiddenException();
                            }

                            path1 = Uri.UnescapeDataString(path1);
                            var path2 = wwwroot + path1;

                            if (path1.StartsWith("..") || path1.StartsWith("/.."))
                            {
                                throw new ForbiddenException();
                            }

                            try
                            {
                                if (!reqline[0].Split(' ')[2].StartsWith("HTTP/"))
                                {
                                    throw new BadRequestException();
                                }
                            }
                            catch
                            {
                                throw new BadRequestException();
                            }

                            WriteLog(loglevel, 3, String.Format("{0} - {1}: \"{2}\"", DateTime.Now, c.Client.RemoteEndPoint, reqline[0].Substring(0, reqline[0].Length - 1)));

                            if (reqline[0].StartsWith("GET ") || reqline[0].StartsWith("HEAD "))
                            {
                                ProcessGET(c, ns, w, req, reqline, ref path1, ref path2);
                            }
                            else if (reqline[0].StartsWith("POST "))
                            {
                                ProcessPOST(c, ns, w, req, path2);

                            }
                            else
                            {
                                ProcessVerbNotImplemented(w);
                            }
                        }
                        catch (BadRequestException e)
                        {
                            ProcessBadRequest(w, req);
                        }
                        catch (NotFoundException e)
                        {
                            //Console.WriteLine(e);
                            ProcessNotFound(w, reqline[0], path1);
                        }
                        catch (ForbiddenException e)
                        {
                            ProcessForbidden(w, reqline[0], path1, serverstring);
                        }
                        catch (Exception e)
                        {
                            Console.WriteLine(e.Message);
                        }
                    }
                }
            }
            c.Close();
        }
        
        private static void InitLog()
        {
            if (!Directory.Exists(logroot))
            {
                Directory.CreateDirectory(logroot);
            }
            log = new StreamWriter(logroot + "/" + DateTime.Today.ToString("yyyy-MM-dd") + ".log", true);
            log.AutoFlush = true;
        }

        private static void StartServer()
        {
            try
            {
                server = new TcpListener(IPAddress.Parse(listenaddress), port);
                server.Start();
            }
            catch (Exception e)
            {
                WriteLog(loglevel, 1, String.Format("{0} - ERROR: {1}", DateTime.Now, e.Message));
                Environment.Exit(1);
            }
        }

        private static void ProcessHttpRequests()
        {
            while (true)
            {
                var a = server.AcceptTcpClient();
                new Thread(new ThreadStart(() => HandleRequest(a))).Start();
            }
        }

        static void Main(string[] args)
        {
            InitLog();
            StartServer();
            ProcessHttpRequests();
        }
    }
}
