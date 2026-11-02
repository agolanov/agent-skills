// Windows PowerShell 5.1 / C# 5. No compiler, package or Python installation.
using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using System.Numerics;
using System.Diagnostics;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Security.Cryptography;
using System.Threading.Tasks;
using Microsoft.Win32.SafeHandles;
namespace CheckoutState {
    // Deliberately small strict JSON codec: integer tokens never pass through Double.
    public static class Json {
        public static string Write(object value) {
            if(value==null) return "null";
            if(value is string) {
                var b=new StringBuilder("\"");
                foreach(char c in (string)value) {
                    if(c=='"'||c=='\\') b.Append('\\').Append(c);
                    else if(c<32||c>126) b.Append("\\u").Append(((int)c).ToString("x4"));
                    else b.Append(c);
                }
                return b.Append('"').ToString();
            }
            if(value is bool) return (bool)value?"true":"false";
            var d=value as IDictionary<string,object>;
            if(d!=null) return "{"+String.Join(",",d.Keys.OrderBy(k=>k,StringComparer.Ordinal).Select(k=>Write(k)+":"+Write(d[k])))+"}";
            if(value is IEnumerable) {
                var parts=new List<string>();
                foreach(object x in (IEnumerable)value) parts.Add(Write(x));
                return "["+String.Join(",",parts)+"]";
            }
            if(value is BigInteger||value is int||value is long||value is uint||value is ulong) return Convert.ToString(value,System.Globalization.CultureInfo.InvariantCulture);
            throw new InvalidDataException("unsupported JSON type");
        }
        public static object Read(string value) {
            var p=new Parser(value);
            object x=p.Value();
            p.Space();
            if(p.At!=value.Length) throw new InvalidDataException("trailing JSON");
            return x;
        }
        class Parser {
            string s;
            public int At;
            int depth;
            public Parser(string value) {
                s=value;
            }
            public void Space() {
                while(At<s.Length&&" \r\n\t".IndexOf(s[At])>=0)At++;
            }
            char Take() {
                if(At==s.Length)throw new InvalidDataException("truncated JSON");
                return s[At++];
            }
            string String() {
                if(Take()!='"')throw new InvalidDataException("expected string");
                var b=new StringBuilder();
                while(true) {
                    char c=Take();
                    if(c=='"')return b.ToString();
                    if(c<32)throw new InvalidDataException("control in JSON");
                    if(c=='\\') {
                        c=Take();
                        switch(c) {
                            case '"':case '\\':case '/':break;
                            case 'b':c='\b';
                            break;
                            case 'f':c='\f';
                            break;
                            case 'n':c='\n';
                            break;
                            case 'r':c='\r';
                            break;
                            case 't':c='\t';
                            break;
                            case 'u': if(At+4>s.Length)throw new InvalidDataException("truncated escape");
                            c=(char)Convert.ToInt32(s.Substring(At,4),16);
                            At+=4;
                            break;
                            default:throw new InvalidDataException("invalid escape");
                        }
                    }
                    b.Append(c);
                }
            }
            public object Value() {
                Space();
                if(++depth>128)throw new InvalidDataException("JSON nesting bound");
                try {
                    if(At==s.Length)throw new InvalidDataException("missing JSON");
                    char c=s[At];
                    if(c=='"')return String();
                    if(c=='[') {
                        At++;
                        var a=new List<object>();
                        Space();
                        if(At<s.Length&&s[At]==']') {
                            At++;
                            return a;
                        }
                        while(true) {
                            a.Add(Value());
                            Space();
                            c=Take();
                            if(c==']')return a;
                            if(c!=',')throw new InvalidDataException("array separator");
                        }
                    }
                    if(c=='{') {
                        At++;
                        var d=new Dictionary<string,object>(StringComparer.Ordinal);
                        Space();
                        if(At<s.Length&&s[At]=='}') {
                            At++;
                            return d;
                        }
                        while(true) {
                            Space();
                            string k=String();
                            Space();
                            if(Take()!=':')throw new InvalidDataException("object separator");
                            if(d.ContainsKey(k))throw new InvalidDataException("duplicate JSON key");
                            d.Add(k,Value());
                            Space();
                            c=Take();
                            if(c=='}')return d;
                            if(c!=',')throw new InvalidDataException("object separator");
                        }
                    }
                    foreach(string word in new[] {
                        "null","true","false"
                    }
                    )if(s.Substring(At).StartsWith(word,StringComparison.Ordinal)) {
                        At+=word.Length;
                        return word=="null"?null:(object)(word=="true");
                    }
                    int start=At;
                    if(c=='-')At++;
                    if(At==s.Length||s[At]<'0'||s[At]>'9')throw new InvalidDataException("invalid JSON token");
                    if(s[At]=='0')At++;
                    else while(At<s.Length&&s[At]>='0'&&s[At]<='9')At++;
                    return BigInteger.Parse(s.Substring(start,At-start),System.Globalization.CultureInfo.InvariantCulture);
                }
                finally {
                    depth--;
                }
            }
        }
    }
    public sealed class Native : IDisposable {
        const uint ReadAccess=0x80000000, Attributes=0x80, OpenExisting=3, Backup=0x02000000, Reparse=0x00200000;
        [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFileW(string p,uint access,uint share,IntPtr sec,uint disposition,uint flags,IntPtr template);
        [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandleEx(SafeFileHandle h,int cls,byte[] b,uint size);
        [DllImport("kernel32.dll",SetLastError=true)] static extern bool DeviceIoControl(SafeFileHandle h,uint code,IntPtr input,uint inputSize,byte[] output,uint size,out uint returned,IntPtr overlapped);
        [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern uint GetFinalPathNameByHandleW(SafeFileHandle h,StringBuilder b,uint size,uint flags);
        [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateDirectoryW(string path,ref SecurityAttributes attributes);
        [StructLayout(LayoutKind.Sequential)] struct SecurityAttributes {
            public int length;
            public IntPtr descriptor;
            public int inherit;
        }
        public SafeFileHandle Handle;
        public string PathName;
        public uint Flags;
        public uint Tag;
        public long MTime;
        public long Size;
        public object[] Id;
        List<Native> parents=new List<Native>();
        static void Failure(string operation) {
            throw new Win32Exception(Marshal.GetLastWin32Error(),operation);
        }
        static string Extended(string p) {
            return p.StartsWith(@"\\",StringComparison.Ordinal)?@"\\?\UNC\"+p.Substring(2):@"\\?\"+p;
        }
        static Native Single(string p,bool data,bool administrative) {
            var n=new Native();
            n.PathName=p;
            n.Handle=CreateFileW(Extended(p),data?ReadAccess:(Attributes|1U),administrative?1U:3U,IntPtr.Zero,OpenExisting,Backup|Reparse,IntPtr.Zero);
            if(n.Handle.IsInvalid) {
                int e=Marshal.GetLastWin32Error();
                n.Handle.Dispose();
                if(e==2||e==3)throw new FileNotFoundException(p);
                throw new Win32Exception(e,"open no-follow: "+p);
            }
            try {
                n.Refresh();
                return n;
            }
            catch {
                n.Dispose();
                throw;
            }
        }
        public static string Absolute(string p) {
            if(String.IsNullOrEmpty(p)||!System.Text.RegularExpressions.Regex.IsMatch(p,@"\A(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+(?:[\\/]|\z))")||p.StartsWith(@"\\?\")||p.StartsWith(@"\\.\")||p.IndexOf('\0')>=0)throw new InvalidDataException("ordinary absolute native path required");
            string full=System.IO.Path.GetFullPath(p);
            if(full.Length<3||(!full.StartsWith(@"\\")&&full[1]!=':'))throw new InvalidDataException("drive-relative path refused");
            return full.TrimEnd('\\','/').Length==2?full:full.TrimEnd('\\','/');
        }
        public static Native Open(string path,bool directory,bool data,bool administrative) {
            string p=Absolute(path),root=System.IO.Path.GetPathRoot(p);
            var held=new List<Native>();
            try {
                Native top=Single(root,false,false);
                held.Add(top);
                if((top.Flags&0x400)!=0)throw new IOException("reparse root refused");
                string[] parts=p.Substring(root.Length).Split(new[] {
                    '\\','/'
                }
                ,StringSplitOptions.RemoveEmptyEntries);
                string at=root;
                for(int i=0;
                i<parts.Length;
                i++) {
                    at=System.IO.Path.Combine(at,parts[i]);
                    bool last=i==parts.Length-1;
                    Native n=Single(at,last&&data,last&&administrative&&!directory);
                    held.Add(n);
                    if((!last||administrative)&&((n.Flags&0x400)!=0))throw new IOException("administrative reparse traversal refused: "+at);
                    if((!last||directory)&&(n.Flags&16)==0)throw new IOException("directory required: "+at);
                }
                Native result=held[held.Count-1];
                held.RemoveAt(held.Count-1);
                result.parents=held;
                return result;
            }
            catch {
                foreach(var n in held)n.Dispose();
                throw;
            }
        }
        byte[] Info(int cls,int size) {
            byte[] b=new byte[size];
            if(!GetFileInformationByHandleEx(Handle,cls,b,(uint)size))Failure("native metadata unavailable (class "+cls+")");
            return b;
        }
        void Refresh() {
            byte[] id=Info(18,24),basic=Info(0,40),standard=Info(1,24),tag=Info(9,8);
            byte[] wide=new byte[17];
            Array.Copy(id,8,wide,0,16);
            Id=new object[] {
                new BigInteger(BitConverter.ToUInt64(id,0)),new BigInteger(wide)
            }
            ;
            Flags=BitConverter.ToUInt32(tag,0);
            Tag=BitConverter.ToUInt32(tag,4);
            MTime=BitConverter.ToInt64(basic,16);
            Size=BitConverter.ToInt64(standard,8);
        }
        string Identity() {
            return Json.Write(new object[] {
                Id,Flags,Tag,MTime,Size,BitConverter.ToInt64(Info(0,40),24)
            }
            );
        }
        public string FinalPath() {
            var b=new StringBuilder(32768);
            uint length=GetFinalPathNameByHandleW(Handle,b,(uint)b.Capacity,0);
            if(length==0||length>=b.Capacity)Failure("final native path unavailable");
            string p=b.ToString();
            return p.StartsWith(@"\\?\UNC\")?@"\\"+p.Substring(8):p.StartsWith(@"\\?\")?p.Substring(4):p;
        }
        public byte[] Bytes(int limit) {
            if((Flags&(16|0x400|0x40))!=0||Size>limit)throw new IOException("ordinary bounded file required");
            string before=Identity();
            using(var stream=new FileStream(Handle,FileAccess.Read)) {
                using(var m=new MemoryStream()) {
                    byte[] b=new byte[1024*1024];
                    int n;
                    while((n=stream.Read(b,0,b.Length))>0) {
                        if(m.Length+n>limit)throw new IOException("read bound exceeded");
                        m.Write(b,0,n);
                    }
                    Refresh();
                    if(before!=Identity())throw new IOException("native file changed during read");
                    return m.ToArray();
                }
            }
        }
        public Dictionary<string,object> Observe(bool literal,bool executable) {
            string before=Identity();
            Dictionary<string,object> r;
            if((Flags&0x400)!=0) {
                if(Tag!=0xA000000CU&&Tag!=0xA0000003U)throw new IOException("unsupported reparse tag: "+Tag.ToString("x"));
                byte[] b=new byte[16384];
                uint len;
                if(!DeviceIoControl(Handle,0x000900A8,IntPtr.Zero,0,b,(uint)b.Length,out len,IntPtr.Zero))Failure("literal reparse target");
                int offset=BitConverter.ToUInt16(b,8),size=BitConverter.ToUInt16(b,10),start=Tag==0xA000000C?20:16;
                if(start+offset+size>len||size%2!=0)throw new IOException("invalid reparse target");
                string target=new UnicodeEncoding(false,false,true).GetString(b,start+offset,size);
                r=Engine.D("kind","symlink","target",Engine.B64(Engine.Utf8.GetBytes(target)));
            }
            else if((Flags&16)!=0)r=Engine.D("kind","directory");
            else if((Flags&0x40)!=0)throw new IOException("unsupported device metadata");
            else {
                using(var stream=new FileStream(Handle,FileAccess.Read)) {
                    using(var hash=SHA256.Create()) {
                        byte[] b=new byte[1024*1024];
                        MemoryStream text=literal?new MemoryStream():null;
                        int n;
                        while((n=stream.Read(b,0,b.Length))>0) {
                            hash.TransformBlock(b,0,n,null,0);
                            if(text!=null) {
                                if(text.Length+n>268435456)throw new IOException("literal metadata too large");
                                text.Write(b,0,n);
                            }
                        }
                        hash.TransformFinalBlock(new byte[0],0,0);
                        r=Engine.D("kind","file","sha256",Engine.Hex(hash.Hash),"executable",executable);
                        if(text!=null) {
                            r["literal"]=Engine.B64(text.ToArray());
                            text.Dispose();
                        }
                        Refresh();
                        if(before!=Identity())throw new IOException("native file changed during hash");
                        return r;
                    }
                }
            }
            Refresh();
            if(before!=Identity())throw new IOException("native entry changed during observation");
            return r;
        }
        public string[] Names() {
            if((Flags&16)==0||(Flags&0x400)!=0)throw new IOException("ordinary directory required");
            var names=new List<string>();
            byte[] b=new byte[65536];
            int cls=15;
            while(true) {
                if(!GetFileInformationByHandleEx(Handle,cls,b,(uint)b.Length)) {
                    int e=Marshal.GetLastWin32Error();
                    if(e==18)break;
                    throw new Win32Exception(e,"directory enumeration unavailable (Win32 "+e+")");
                }
                cls=14;
                int at=0;
                while(true) {
                    uint next=BitConverter.ToUInt32(b,at),len=BitConverter.ToUInt32(b,at+60);
                    if(len%2!=0||at+68+len>b.Length)throw new IOException("invalid native directory record");
                    string name=new UnicodeEncoding(false,false,true).GetString(b,at+68,(int)len);
                    if(name!="."&&name!="..")names.Add(name);
                    if(next==0)break;
                    if(next<68||at+next>=b.Length)throw new IOException("invalid directory offset");
                    at+=(int)next;
                }
            }
            return names.ToArray();
        }
        public static bool Exists(string p) {
            try {
                using(var n=Open(p,false,false,false))return true;
            }
            catch(FileNotFoundException) {
                return false;
            }
        }
        public static void PrivateAcl(string path,bool directory) {
            FileSystemSecurity acl=directory?(FileSystemSecurity)Directory.GetAccessControl(path):File.GetAccessControl(path);
            var user=WindowsIdentity.GetCurrent().User;
            if(!acl.GetOwner(typeof(SecurityIdentifier)).Equals(user))throw new IOException("request owner mismatch");
            foreach(FileSystemAccessRule rule in acl.GetAccessRules(true,true,typeof(SecurityIdentifier))) {
                if(rule.AccessControlType!=AccessControlType.Allow||(rule.PropagationFlags&PropagationFlags.InheritOnly)!=0)continue;
                string sid=rule.IdentityReference.Value;
                if(sid==user.Value||sid=="S-1-5-18"||sid=="S-1-5-32-544")continue;
                var unsafeRights=FileSystemRights.Write|FileSystemRights.Delete|FileSystemRights.ChangePermissions|FileSystemRights.TakeOwnership|FileSystemRights.DeleteSubdirectoriesAndFiles;
                if((rule.FileSystemRights&unsafeRights)!=0||((uint)rule.FileSystemRights&0x50000000U)!=0)throw new IOException("request ACL permits foreign mutation");
            }
        }
        public static void MakePrivate(string path) {
            using(var pinnedParent=Open(System.IO.Path.GetDirectoryName(path),true,false,true)) {
                var security=new DirectorySecurity();
                var user=WindowsIdentity.GetCurrent().User;
                security.SetOwner(user);
                security.SetAccessRuleProtection(true,false);
                security.AddAccessRule(new FileSystemAccessRule(user,FileSystemRights.FullControl,InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit,PropagationFlags.None,AccessControlType.Allow));
                byte[] descriptor=security.GetSecurityDescriptorBinaryForm();
                IntPtr ptr=Marshal.AllocHGlobal(descriptor.Length);
                try {
                    Marshal.Copy(descriptor,0,ptr,descriptor.Length);
                    var sa=new SecurityAttributes {
                        length=Marshal.SizeOf(typeof(SecurityAttributes)),descriptor=ptr,inherit=0
                    }
                    ;
                    if(!CreateDirectoryW(Extended(path),ref sa))Failure("exclusive private directory creation");
                }
                finally {
                    Marshal.FreeHGlobal(ptr);
                }
            }
        }
        public void Dispose() {
            if(Handle!=null) {
                Handle.Dispose();
                Handle=null;
            }
            for(int i=parents.Count-1;
            i>=0;
            i--)parents[i].Dispose();
            parents.Clear();
        }
    }
    public static class Engine {
        public static void ValidateRuntimeRoot(string root,string[] protectedRoots) {
            using(var pinned=Native.Open(root,true,false,true)) {
                Native.PrivateAcl(root,true);
                Outside(root,protectedRoots??new string[0]);
            }
        }
        public static string OwnerScript;
        public const string Limits="ignored untracked paths not monitored; submodule/nested-repository content not recursively monitored; special-file contents not monitored; submodule resolved HEAD and dirty state not monitored";
        public static readonly UTF8Encoding Utf8=new UTF8Encoding(false,true);
        static readonly System.Text.RegularExpressions.Regex Oid=new System.Text.RegularExpressions.Regex("\\A(?:[0-9a-f]{40}|[0-9a-f]{64})\\z");
        public static Dictionary<string,object> D(params object[] p) {
            var d=new Dictionary<string,object>(StringComparer.Ordinal);
            for(int i=0;
            i<p.Length;
            i+=2)d.Add((string)p[i],p[i+1]);
            return d;
        }
        static Dictionary<string,object> Map(object o) {
            var d=o as Dictionary<string,object>;
            if(d==null)throw new InvalidDataException("object required");
            return d;
        }
        static List<object> List(object o) {
            var a=o as IEnumerable;
            if(a==null||o is string||o is IDictionary)throw new InvalidDataException("array required");
            return a.Cast<object>().ToList();
        }
        public static string B64(byte[] b) {
            return Convert.ToBase64String(b);
        }
        static string Enc(string s) {
            return B64(Utf8.GetBytes(s));
        }
        static byte[] Dec(object o) {
            if(!(o is string))throw new InvalidDataException("base64 string required");
            byte[] b=Convert.FromBase64String((string)o);
            if(B64(b)!=(string)o)throw new InvalidDataException("noncanonical base64");
            return b;
        }
        static string Text(object o) {
            return Utf8.GetString(Dec(o));
        }
        public static string Hex(byte[] b) {
            return BitConverter.ToString(b).Replace("-","").ToLowerInvariant();
        }
        static string Hash(byte[] b) {
            using(var h=SHA256.Create())return Hex(h.ComputeHash(b));
        }
        static bool Eq(object a,object b) {
            return Json.Write(a)==Json.Write(b);
        }
        public static string Quote(string s) {
            var b=new StringBuilder("\"");
            int slashes=0;
            foreach(char c in s) {
                if(c=='\\') {
                    slashes++;
                    continue;
                }
                if(c=='"') {
                    b.Append('\\',slashes*2+1).Append(c);
                    slashes=0;
                    continue;
                }
                b.Append('\\',slashes).Append(c);
                slashes=0;
            }
            return b.Append('\\',slashes*2).Append('"').ToString();
        }
        public sealed class Result {
            public int ExitCode;
            public string Executable;
            public string[] Arguments;
            public byte[] Stdout;
            public byte[] Stderr;
        }
        public static Result Run(string exe,string[] args,string cwd,Dictionary<string,string> env,byte[] input,int timeout) {
            var psi=new ProcessStartInfo(exe,String.Join(" ",args.Select(Quote)));
            psi.UseShellExecute=false;
            psi.CreateNoWindow=true;
            psi.WorkingDirectory=cwd;
            psi.RedirectStandardOutput=true;
            psi.RedirectStandardError=true;
            psi.RedirectStandardInput=true;
            if(env!=null) {
                psi.EnvironmentVariables.Clear();
                foreach(var pair in env)psi.EnvironmentVariables[pair.Key]=pair.Value;
            }
            using(var p=new Process()) {
                p.StartInfo=psi;
                if(!p.Start())throw new IOException("process start failed");
                var output=new MemoryStream();
                var error=new MemoryStream();
                Task outTask=p.StandardOutput.BaseStream.CopyToAsync(output),errTask=p.StandardError.BaseStream.CopyToAsync(error);
                Task inTask=Task.Factory.StartNew(()=> {
                    try {
                        if(input!=null)p.StandardInput.BaseStream.Write(input,0,input.Length);
                    }
                    finally {
                        p.StandardInput.Close();
                    }
                }
                );
                if(!p.WaitForExit(timeout)) {
                    try {
                        p.Kill();
                    }
                    catch {
                    }
                    throw new TimeoutException("native process exceeded deadline");
                }
                if(!Task.WaitAll(new[] {
                    outTask,errTask,inTask
                }
                ,1000))throw new TimeoutException("native process streams did not close");
                return new Result {
                    ExitCode=p.ExitCode,Executable=exe,Arguments=args,Stdout=output.ToArray(),Stderr=error.ToArray()
                }
                ;
            }
        }
        static Dictionary<string,string> EnvironmentForGit() {
            var e=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
            foreach(DictionaryEntry x in Environment.GetEnvironmentVariables())if(!((string)x.Key).StartsWith("GIT_",StringComparison.OrdinalIgnoreCase))e[(string)x.Key]=(string)x.Value;
            e["GIT_CONFIG_NOSYSTEM"]="1";
            e["GIT_CONFIG_SYSTEM"]="NUL";
            e["GIT_CONFIG_GLOBAL"]="NUL";
            e["GIT_OPTIONAL_LOCKS"]="0";
            e["GIT_NO_REPLACE_OBJECTS"]="1";
            e["GIT_TERMINAL_PROMPT"]="0";
            e["GIT_ATTR_NOSYSTEM"]="1";
            e["MSYS2_ARG_CONV_EXCL"]="*";
            e["MSYS_NO_PATHCONV"]="1";
            return e;
        }
        static string FindGit() {
            foreach(string dir in (Environment.GetEnvironmentVariable("PATH")??"").Split(';')) {
                string path;
                try {
                    path=System.IO.Path.Combine(dir.Trim('"'),"git.exe");
                }
                catch {
                    continue;
                }
                if(File.Exists(path))return Native.Absolute(path);
            }
            throw new IOException("native Git executable unavailable");
        }
        static byte[] AdminRead(string p,bool optional,int limit) {
            try {
                using(var n=Native.Open(p,false,true,true))return n.Bytes(limit);
            }
            catch(FileNotFoundException) {
                if(optional)return null;
                throw;
            }
        }
        static string Canonical(string p) {
            using(var n=Native.Open(p,true,false,true))return n.FinalPath();
        }
        static bool Inside(string candidate,string root) {
            candidate=Native.Absolute(candidate);
            root=Canonical(root);
            string probe=candidate;
            while(!Native.Exists(probe)) {
                string parent=System.IO.Path.GetDirectoryName(probe);
                if(String.IsNullOrEmpty(parent)||parent==probe)break;
                probe=parent;
            }
            using(var n=Native.Open(probe,false,false,true)) {
                string final=n.FinalPath();
                if(final.Equals(root,StringComparison.OrdinalIgnoreCase)||final.StartsWith(root.TrimEnd('\\')+"\\",StringComparison.OrdinalIgnoreCase))return true;
            }
            // Identity comparison also detects case aliases, short names and mount aliases.
            using(var r=Native.Open(root,true,false,true)) {
                probe=candidate;
                while(!String.IsNullOrEmpty(probe)) {
                    if(Native.Exists(probe))using(var n=Native.Open(probe,false,false,true)) {
                        if(Eq(n.Id,r.Id))return true;
                    }
                    string parent=System.IO.Path.GetDirectoryName(probe);
                    if(parent==probe)break;
                    probe=parent;
                }
            }
            return false;
        }
        static void Outside(string p,IEnumerable<string> roots) {
            foreach(string root in roots)if(Inside(p,root))throw new IOException("output/runtime must be outside checkout and administration: "+p);
        }
        static string TempRoot() {
            string p=null;
            foreach(string key in new[] {
                "TMPDIR","TEMP","TMP"
            }
            ) {
                p=Environment.GetEnvironmentVariable(key);
                if(!String.IsNullOrEmpty(p))break;
            }
            return Canonical(String.IsNullOrEmpty(p)?System.IO.Path.GetTempPath():p);
        }
        static string SafeGitPath(string s) {
            if(String.IsNullOrEmpty(s)||s.StartsWith("/")||s.Contains("\\")||s.Contains(":"))throw new InvalidDataException("unsafe/unrepresentable native Git path");
            foreach(string part in s.Split('/')) {
                if(part==""||part=="."||part==".."||part.Equals(".git",StringComparison.OrdinalIgnoreCase)||part.EndsWith(".")||part.EndsWith(" ")||System.Text.RegularExpressions.Regex.IsMatch(part,@"\A(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|\z)",System.Text.RegularExpressions.RegexOptions.IgnoreCase))throw new InvalidDataException("unsafe/unrepresentable native Git component");
            }
            Utf8.GetBytes(s);
            return s;
        }
        static List<string> Nul(byte[] b) {
            if(b.Length==0)return new List<string>();
            if(b[b.Length-1]!=0)throw new InvalidDataException("unterminated NUL inventory");
            return Utf8.GetString(b,0,b.Length-1).Split('\0').ToList();
        }
        sealed class View:IDisposable {
            public string Root,GitDir,Common,Private,Git;
            public Dictionary<string,object> Administration;
            List<Native> pinned=new List<Native>();
            public View(string root) {
                Root=Canonical(root);
                Git=FindGit();
                string dot=System.IO.Path.Combine(Root,".git");
                byte[] pointer=null;
                var location=Native.Open(dot,false,false,true);
                pinned.Add(location);
                if((location.Flags&16)!=0)GitDir=dot;
                else {
                    pointer=AdminRead(dot,false,65536);
                    string value=Utf8.GetString(pointer);
                    if(!value.StartsWith("gitdir: ")||value.IndexOf('\0')>=0)throw new IOException("invalid outer gitfile");
                    GitDir=Native.Absolute(System.IO.Path.Combine(Root,value.Substring(8).TrimEnd('\r','\n')));
                }
                var gd=Native.Open(GitDir,true,false,true);
                pinned.Add(gd);
                GitDir=gd.FinalPath();
                byte[] cp=AdminRead(System.IO.Path.Combine(GitDir,"commondir"),true,65536);
                Common=cp==null?GitDir:Native.Absolute(System.IO.Path.Combine(GitDir,Utf8.GetString(cp).TrimEnd('\r','\n')));
                var cd=Native.Open(Common,true,false,true);
                pinned.Add(cd);
                Common=cd.FinalPath();
                Administration=D("gitfile",pointer==null?null:B64(pointer),"location",location.Id,"gitdir",Enc(GitDir),"gitdir_identity",gd.Id,"commondir",Enc(Common),"common_pointer",cp==null?null:B64(cp),"common_identity",cd.Id);
                string temp=TempRoot();
                Outside(temp,new[] {
                    Root,GitDir,Common
                }
                );
                Private=System.IO.Path.Combine(temp,"checkout-state-admin-"+Guid.NewGuid().ToString("N"));
                Native.MakePrivate(Private);
                try {
                    byte[] config=AdminRead(System.IO.Path.Combine(Common,"config"),true,8388608)??new byte[0];
                    string source=System.IO.Path.Combine(Private,"source-config");
                    File.WriteAllBytes(source,config);
                    var env=EnvironmentForGit();
                    env["GIT_CEILING_DIRECTORIES"]=temp;
                    Result parsed=Run(Git,new[] {
                        "config","--file",source,"--no-includes","--null","--list"
                    }
                    ,Private,env,null,10000);
                    if(parsed.ExitCode!=0)throw new IOException("unreadable repository config");
                    string format="sha1";
                    foreach(string item in Nul(parsed.Stdout)) {
                        int split=item.IndexOf('\n');
                        string key=split<0?item:item.Substring(0,split),value=split<0?"":item.Substring(split+1);
                        if(key=="extensions.objectformat")format=value;
                        else if(key.StartsWith("extensions.")&&key!="extensions.worktreeconfig")throw new IOException("unsupported repository extension: "+key);
                    }
                    if(format!="sha1"&&format!="sha256")throw new IOException("unsupported object format");
                    File.WriteAllText(System.IO.Path.Combine(Private,"config"),"[core]\nrepositoryformatversion = "+(format=="sha256"?"1":"0")+"\nbare = false\nhooksPath = NUL\nfsmonitor = false\nexcludesFile = NUL\nattributesFile = NUL\nautocrlf = false\nsafecrlf = false\nfilemode = false\n"+(format=="sha256"?"[extensions]\nobjectformat = sha256\n":""),Utf8);
                    Copy(GitDir,"HEAD",false);
                    Copy(GitDir,"index",true);
                    Copy(Common,"packed-refs",true);
                    Copy(Common,"info/exclude",true);
                    foreach(string name in gd.Names())if(System.Text.RegularExpressions.Regex.IsMatch(name,@"\Asharedindex\.[0-9a-f]+\z"))Copy(GitDir,name,false);
                    Directory.CreateDirectory(System.IO.Path.Combine(Private,"refs"));
                    int count=0;
                    CopyRefs("refs",0,ref count);
                    string objects=System.IO.Path.Combine(Common,"objects");
                    pinned.Add(Native.Open(objects,true,false,true));
                    string info=System.IO.Path.Combine(Private,"objects","info");
                    Directory.CreateDirectory(info);
                    byte[] bytes=Utf8.GetBytes(objects.Replace('\\','/'));
                    var quoted=new StringBuilder("\"");
                    foreach(byte b in bytes) {
                        if(b>=32&&b<127&&b!=34&&b!=92)quoted.Append((char)b);
                        else quoted.Append('\\').Append(Convert.ToString(b,8).PadLeft(3,'0'));
                    }
                    File.WriteAllText(System.IO.Path.Combine(info,"alternates"),quoted.Append("\"\n").ToString(),Utf8);
                }
                catch {
                    Dispose();
                    throw;
                }
            }
            public void Copy(string source,string relative,bool optional) {
                string src=System.IO.Path.Combine(source,relative.Replace('/','\\'));
                try {
                    using(var n=Native.Open(src,false,true,true)) {
                        long time=n.MTime;
                        byte[] data=n.Bytes(268435456);
                        string dest=System.IO.Path.Combine(Private,relative.Replace('/','\\'));
                        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(dest));
                        File.WriteAllBytes(dest,data);
                        File.SetLastWriteTimeUtc(dest,DateTime.FromFileTimeUtc(time));
                    }
                }
                catch(FileNotFoundException) {
                    if(!optional)throw;
                }
            }
            void CopyRefs(string relative,int depth,ref int count) {
                if(depth>32||count>100000)throw new IOException("reference inventory exceeds bound");
                string p=System.IO.Path.Combine(Common,relative);
                if(!Native.Exists(p))return;
                using(var n=Native.Open(p,true,false,true)) {
                    foreach(string name in n.Names()) {
                        count++;
                        string rel=relative+"/"+name;
                        using(var entry=Native.Open(System.IO.Path.Combine(Common,rel),false,false,true)) {
                            if((entry.Flags&16)!=0)CopyRefs(rel,depth+1,ref count);
                            else Copy(Common,rel,false);
                        }
                    }
                }
            }
            public Result Call(string[] args,byte[] input,params int[] allowed) {
                var env=EnvironmentForGit();
                env["GIT_DIR"]=Private;
                env["GIT_WORK_TREE"]=Root;
                var vector=new List<string> {
                    "-C",Private
                }
                ;
                vector.AddRange(args);
                Result r=Run(Git,vector.ToArray(),Private,env,input,10000);
                if(!allowed.Contains(r.ExitCode))throw new IOException("isolated Git exit "+r.ExitCode+": "+Utf8.GetString(r.Stderr));
                return r;
            }
            public byte[] Call(params string[] args) {
                return Call(args,null,0).Stdout;
            }
            public void Dispose() {
                foreach(var n in pinned)n.Dispose();
                pinned.Clear();
                if(Private!=null&&Directory.Exists(Private)) {
                    Directory.Delete(Private,true);
                    Private=null;
                }
            }
        }
        static int ByteOrder(string a,string b) {
            byte[] x=Utf8.GetBytes(a),y=Utf8.GetBytes(b);
            for(int i=0;
            i<Math.Min(x.Length,y.Length);
            i++) {
                int n=x[i].CompareTo(y[i]);
                if(n!=0)return n;
            }
            return x.Length.CompareTo(y.Length);
        }
        static string[] Sorted(IEnumerable<string> items) {
            var a=items.ToArray();
            Array.Sort(a,ByteOrder);
            return a;
        }
        static string Local(string root,string relative) {
            return System.IO.Path.Combine(root,relative.Replace('/','\\'));
        }
        static HashSet<string> Set(IEnumerable<string> items) {
            return new HashSet<string>(items,StringComparer.Ordinal);
        }
        // -1 missing, 0 ordinary final leaf, 1 final directory, 2 blocked ancestor.
        static int LocationState(View view,string relative) {
            var held=new List<Native>();
            try {
                string[] parts=relative.Split('/');
                string at="";
                for(int i=0;i<parts.Length;i++) {
                    at+=(i==0?"":"/")+parts[i];
                    Native n;
                    try { n=Native.Open(Local(view.Root,at),false,false,false); }
                    catch(FileNotFoundException) { return -1; }
                    held.Add(n);
                    bool directory=(n.Flags&(16|0x400))==16;
                    if(i==parts.Length-1)return directory?1:0;
                    if(!directory)return 2;
                }
                throw new IOException("empty relative location");
            } finally { foreach(var n in held)n.Dispose(); }
        }
        static Dictionary<string,object> PathRecord(View v,string relative,bool tracked,bool literal,bool executable) {
            // Hold every component against replacement until the whole observation ends.
            var held=new List<Native>();
            try {
                string[] parts=relative.Split('/');
                string at="";
                for(int i=0;
                i<parts.Length;
                i++) {
                    at+=(i==0?"":"/")+parts[i];
                    string p=Local(v.Root,at);
                    Dictionary<string,object> r;
                    try {
                        var n=Native.Open(p,false,true,false);
                        held.Add(n);
                        r=n.Observe(literal&&i==parts.Length-1,executable);
                    }
                    catch(FileNotFoundException) {
                        if(!tracked||Native.Exists(p))throw new IOException("enumerated path disappeared/appeared: "+p);
                        r=D("kind","missing");
                    }
                    if(i==parts.Length-1||(string)r["kind"]!="directory") {
                        r["at"]=Enc(at);
                        return r;
                    }
                }
                throw new IOException("empty relative observation");
            }
            finally {
                foreach(var n in held)n.Dispose();
            }
        }
        static object Nested(View v,string path) {
            var m=PathRecord(v,path+"/.git",true,true,false);
            if((string)m["at"]!=Enc(path+"/.git")||(string)m["kind"]=="missing")return null;
            if((string)m["kind"]=="directory")return D("entry",m,"head",PathRecord(v,path+"/.git/HEAD",true,true,false));
            return m;
        }
        static object Submodule(View v,string path) {
            var location=PathRecord(v,path,true,false,false);
            var r=D("location",location,"metadata_present",false);
            if((string)location["at"]!=Enc(path)||(string)location["kind"]!="directory")return r;
            var m=PathRecord(v,path+"/.git",true,true,false);
            if((string)m["at"]!=Enc(path+"/.git"))throw new IOException("submodule location changed");
            r["metadata"]=m;
            r["metadata_present"]=(string)m["kind"]!="missing";
            if((string)m["kind"]=="directory") {
                var h=PathRecord(v,path+"/.git/HEAD",true,true,false);
                if((string)h["at"]!=Enc(path+"/.git/HEAD"))throw new IOException("submodule metadata changed");
                r["embedded_head"]=h;
            }
            if(!Eq(location,PathRecord(v,path,true,false,false))||!Eq(m,PathRecord(v,path+"/.git",true,true,false)))throw new IOException("submodule metadata changed");
            return r;
        }
        static string[] Discover(View v,HashSet<string> tracked,HashSet<string> links) {
            var found=Set(new string[0]);
            var dirs=Set(new string[0]);
            foreach(string p in tracked) {
                int at=p.IndexOf('/');
                while(at>=0) {
                    dirs.Add(p.Substring(0,at));
                    at=p.IndexOf('/',at+1);
                }
            }
            Walk(v,"",tracked,links,dirs,found,0);
            return Sorted(found);
        }
        static void Walk(View v,string prefix,HashSet<string> tracked,HashSet<string> links,HashSet<string> dirs,HashSet<string> found,int depth) {
            if(depth>1024)throw new IOException("directory depth exceeds bound");
            using(var dir=Native.Open(Local(v.Root,prefix),true,false,true)) {
                string[] names=Sorted(dir.Names().Where(n=>!n.Equals(".git",StringComparison.OrdinalIgnoreCase)));
                string[] paths=names.Select(n=>SafeGitPath(prefix+n)).ToArray();
                var ignored=Set(new string[0]);
                if(paths.Length>0) {
                    byte[] input=Utf8.GetBytes(String.Join("\0",paths.Select(p=>"./"+p))+"\0");
                    foreach(string p in Nul(v.Call(new[] {
                        "check-ignore","--stdin","-z"
                    }
                    ,input,0,1).Stdout)) {
                        if(!p.StartsWith("./"))throw new IOException("invalid ignored pathname");
                        ignored.Add(p.Substring(2));
                    }
                }
                foreach(string path in paths) {
                    if(links.Contains(path)||(ignored.Contains(path)&&!tracked.Contains(path)))continue;
                    using(var n=Native.Open(Local(v.Root,path),false,false,false)) {
                        if((n.Flags&(16|0x400))==16) {
                            if(Native.Exists(Local(v.Root,path+"/.git"))) {
                                if(!tracked.Contains(path))found.Add(path);
                                if(dirs.Contains(path))Walk(v,path+"/",tracked,links,dirs,found,depth+1);
                            }
                            else Walk(v,path+"/",tracked,links,dirs,found,depth+1);
                        }
                        else if(!tracked.Contains(path))found.Add(path);
                    }
                }
                if(!names.SequenceEqual(Sorted(dir.Names().Where(n=>!n.Equals(".git",StringComparison.OrdinalIgnoreCase)))))throw new IOException("directory inventory changed during discovery");
            }
        }
        static Dictionary<string,object> Inventory(View v) {
            string head=Utf8.GetString(v.Call("rev-parse","--verify","HEAD")).TrimEnd('\r','\n');
            if(!Oid.IsMatch(head))throw new IOException("invalid HEAD");
            var entries=new List<object>();
            foreach(string item in Nul(v.Call("ls-files","--stage","-z"))) {
                int tab=item.IndexOf('\t');
                if(tab<0)throw new IOException("invalid index entry");
                string[] h=item.Substring(0,tab).Split(' ');
                if(h.Length!=3)throw new IOException("invalid index header");
                entries.Add(D("path",Enc(SafeGitPath(item.Substring(tab+1))),"mode",h[0],"oid",h[1],"stage",Int32.Parse(h[2],System.Globalization.CultureInfo.InvariantCulture)));
            }
            var flags=new List<object>();
            foreach(string item in Nul(v.Call("ls-files","-v","-z"))) {
                if(item.Length<3||item[1]!=' ')throw new IOException("invalid index flag");
                flags.Add(D("path",Enc(SafeGitPath(item.Substring(2))),"flag",item.Substring(0,1)));
            }
            var tracked=Set(entries.Select(e=>Text(Map(e)["path"])));
            var links=Set(entries.Where(e=>(string)Map(e)["mode"]=="160000").Select(e=>Text(Map(e)["path"])));
            string[] others=Discover(v,tracked,links);
            var replaced=Set(new string[0]);
            foreach(string path in tracked.Except(links)) {
                if(LocationState(v,path)>0)replaced.Add(path);
            }
            var args=new List<string> {
                "status","--porcelain=v1","-z","--untracked-files=no","--ignore-submodules=all"
            }
            ;
            string[] excluded=Sorted(links.Union(replaced));
            if(excluded.Length>0) {
                args.Add("--");
                args.AddRange(excluded.Select(p=>":(exclude,literal)"+p));
            }
            string index=System.IO.Path.Combine(v.Private,"index");
            DateTime? time=entries.Count>0?(DateTime?)File.GetLastWriteTimeUtc(index):null;
            var zero=Set(entries.Where(e=>Integer(Map(e)["stage"])==0).Select(e=>Text(Map(e)["path"])));
            foreach(string option in new[] {
                "--no-assume-unchanged","--no-skip-worktree"
            }
            ) {
                var paths=new List<string>();
                foreach(object f in flags) {
                    var flag=Map(f);
                    string path=Text(flag["path"]),mark=(string)flag["flag"];
                    if(zero.Contains(path)&&(option=="--no-assume-unchanged"?Char.IsLower(mark[0]):mark.ToUpperInvariant()=="S"&&LocationState(v,path)>=0))paths.Add(path);
                }
                if(paths.Count>0)v.Call(new[] {
                    "update-index",option,"-z","--stdin"
                }
                ,Utf8.GetBytes(String.Join("\0",Sorted(paths))+"\0"),0);
            }
            if(time.HasValue)File.SetLastWriteTimeUtc(index,time.Value);
            byte[] status=v.Call(args.ToArray());
            status=status.Concat(Utf8.GetBytes(String.Concat(Sorted(replaced).Select(p=>" D "+p+"\0"))+String.Concat(others.Select(p=>"?? "+p+"\0")))).ToArray();
            byte[] staged=v.Call("diff-index","--cached","--raw","-z","--no-ext-diff","--no-textconv","--no-renames","--ignore-submodules=dirty",head,"--");
            StatusPaths(B64(status));
            return D("administration",v.Administration,"head",head,"index",entries,"flags",flags,"untracked",others.Select(Enc).ToArray(),"status",B64(status),"staged",B64(staged));
        }
        static void Observe(View v,Dictionary<string,object> fields) {
            foreach(var pair in Inventory(v))fields[pair.Key]=pair.Value;
            var tracked=Set(List(fields["index"]).Select(e=>Text(Map(e)["path"])));
            var links=Set(List(fields["index"]).Where(e=>(string)Map(e)["mode"]=="160000").Select(e=>Text(Map(e)["path"])));
            var executable=Set(List(fields["index"]).Where(e=>(string)Map(e)["mode"]=="100755").Select(e=>Text(Map(e)["path"])));
            foreach(string path in Sorted(tracked.Union(List(fields["untracked"]).Select(Text)))) {
                object value;
                if(links.Contains(path))value=D("submodule",Submodule(v,path));
                else {
                    var r=PathRecord(v,path,tracked.Contains(path),false,executable.Contains(path));
                    if((string)r["kind"]=="directory"&&(string)r["at"]==Enc(path)) {
                        object m=Nested(v,path);
                        if(m!=null) {
                            r["kind"]="repository-directory";
                            r["metadata"]=m;
                        }
                    }
                    value=r;
                }
                fields["path:"+Enc(path)]=value;
            }
        }
        static string[] ProtectedRoots(string checkout) {
            string root=Canonical(checkout),dot=System.IO.Path.Combine(root,".git"),gitdir;
            using(var n=Native.Open(dot,false,false,true)) {
                if((n.Flags&16)!=0)gitdir=dot;
                else {
                    string pointer=Utf8.GetString(AdminRead(dot,false,65536));
                    if(!pointer.StartsWith("gitdir: ")||pointer.Contains("\0"))throw new IOException("invalid outer gitfile");
                    gitdir=Native.Absolute(System.IO.Path.Combine(root,pointer.Substring(8).TrimEnd('\r','\n')));
                }
            }
            gitdir=Canonical(gitdir);
            byte[] cp=AdminRead(System.IO.Path.Combine(gitdir,"commondir"),true,65536);
            string common=cp==null?gitdir:Canonical(System.IO.Path.Combine(gitdir,Utf8.GetString(cp).TrimEnd('\r','\n')));
            return new[] {
                root,gitdir,common
            }
            ;
        }
        static Dictionary<string,object> Capture(string checkout) {
            var fields=D();
            var errors=new List<object>();
            string canonical=Native.Absolute(checkout);
            try {
                using(var view=new View(checkout)) {
                    canonical=view.Root;
                    string top=Canonical(Utf8.GetString(view.Call("rev-parse","--show-toplevel")).TrimEnd('\r','\n'));
                    using(var a=Native.Open(top,true,false,true))using(var b=Native.Open(canonical,true,false,true))if(!Eq(a.Id,b.Id))throw new IOException("checkout must be repository top-level");
                    Observe(view,fields);
                }
                using(var secondView=new View(checkout)) {
                    var second=D();
                    Observe(secondView,second);
                    if(!Eq(fields,second))throw new IOException("observable state changed during capture");
                }
            }
            catch(Exception e) {
                errors.Add(e.GetType().Name+": "+e.Message);
            }
            return D("schema",3,"checkout",Enc(canonical),"complete",errors.Count==0,"fields",fields,"errors",errors,"limits",Limits);
        }
        static BigInteger Integer(object n) {
            if(n is BigInteger)return (BigInteger)n;
            if(n is int)return new BigInteger((int)n);
            if(n is long)return new BigInteger((long)n);
            throw new InvalidDataException("integer required");
        }
        static void Keys(Dictionary<string,object> d,params string[] keys) {
            if(!Set(d.Keys).SetEquals(keys))throw new InvalidDataException("unexpected/missing fields");
        }
        static void Observation(object value) {
            var d=Map(value);
            string kind=(string)d["kind"];
            if(d.ContainsKey("at"))Dec(d["at"]);
            if(!new[] {
                "file","symlink","directory","missing","fifo","socket","character","block","other","repository-directory"
            }
            .Contains(kind))throw new InvalidDataException("invalid file kind");
            if(kind=="file") {
                if(!(d["sha256"] is string)||!System.Text.RegularExpressions.Regex.IsMatch((string)d["sha256"],"\\A[0-9a-f]{64}\\z")||!(d["executable"] is bool))throw new InvalidDataException("invalid file hash/mode");
                if(d.ContainsKey("literal")&&Hash(Dec(d["literal"]))!=(string)d["sha256"])throw new InvalidDataException("literal digest mismatch");
            }
            if(kind=="symlink")Dec(d["target"]);
            if(new[] {
                "fifo","socket","character","block","other"
            }
            .Contains(kind))Integer(d["rdev"]);
            if(kind=="repository-directory") {
                var m=Map(d["metadata"]);
                if(m.ContainsKey("entry")) {
                    Observation(m["entry"]);
                    Observation(m["head"]);
                }
                else Observation(m);
            }
        }
        static void ValidateSub(object value,string path) {
            var s=Map(value);
            if(!s.ContainsKey("location")||!s.ContainsKey("metadata_present")||s.Keys.Except(new[] {
                "location","metadata_present","metadata","embedded_head"
            }
            ).Any())throw new InvalidDataException("invalid submodule fields");
            Observation(s["location"]);
            var l=Map(s["location"]);
            string at=Text(l["at"]);
            if(at!=path&&!path.StartsWith(at+"/",StringComparison.Ordinal))throw new InvalidDataException("invalid submodule location");
            if(!(s["metadata_present"] is bool))throw new InvalidDataException("invalid metadata presence");
            if(at!=path||(string)l["kind"]!="directory") {
                if((bool)s["metadata_present"]||s.Count!=2)throw new InvalidDataException("metadata through blocked location");
                return;
            }
            var m=Map(s["metadata"]);
            Observation(m);
            if((string)m["at"]!=Enc(path+"/.git")||(bool)s["metadata_present"]!=((string)m["kind"]!="missing"))throw new InvalidDataException("metadata presence/location mismatch");
            var observations=new List<Dictionary<string,object>> {
                m
            }
            ;
            if((string)m["kind"]=="directory") {
                var h=Map(s["embedded_head"]);
                Observation(h);
                if((string)h["at"]!=Enc(path+"/.git/HEAD"))throw new InvalidDataException("invalid embedded HEAD location");
                observations.Add(h);
            }
            else if(s.ContainsKey("embedded_head"))throw new InvalidDataException("HEAD outside metadata directory");
            if(observations.Any(o=>(string)o["kind"]=="file"&&!o.ContainsKey("literal")))throw new InvalidDataException("missing literal metadata");
        }
        static bool AbsoluteEvidence(string s) {
            return s.StartsWith("/",StringComparison.Ordinal)||System.Text.RegularExpressions.Regex.IsMatch(s,@"\A[A-Za-z]:[\\/]")||s.StartsWith(@"\\",StringComparison.Ordinal);
        }
        static string EvidencePath(object value) {
            string s=Text(value);
            if(String.IsNullOrEmpty(s)||s.StartsWith("/")||s.Split('/').Any(p=>p==""||p=="."||p==".."||p==".git"))throw new InvalidDataException("unsafe Git path");
            return s;
        }
        static Dictionary<string,object> Validate(object value) {
            var r=Map(value);
            Keys(r,"schema","checkout","complete","fields","errors","limits");
            if(Integer(r["schema"])!=3||!(r["complete"] is bool)||!AbsoluteEvidence(Text(r["checkout"]))||!(r["limits"] is string)||(string)r["limits"]!=Limits)throw new InvalidDataException("invalid schema/completeness/checkout/limits");
            var f=Map(r["fields"]);
            var errors=List(r["errors"]);
            if(errors.Any(e=>!(e is string)))throw new InvalidDataException("invalid errors");
            if((bool)r["complete"]) {
                if(errors.Count>0||new[] {
                    "head","index","flags","untracked","status","staged","administration"
                }
                .Any(k=>!f.ContainsKey(k)))throw new InvalidDataException("incomplete successful snapshot");
            }
            else if(errors.Count==0)throw new InvalidDataException("diagnostic without errors");
            foreach(var pair in f) {
                string k=pair.Key;
                object v=pair.Value;
                if(k=="head") {
                    if(!(v is string)||!Oid.IsMatch((string)v))throw new InvalidDataException("invalid HEAD");
                }
                else if(k=="index") {
                    foreach(object item in List(v)) {
                        var e=Map(item);
                        EvidencePath(e["path"]);
                        if(!new[] {
                            "100644","100755","120000","160000"
                        }
                        .Contains((string)e["mode"])||!Oid.IsMatch((string)e["oid"])||Integer(e["stage"])<0||Integer(e["stage"])>3)throw new InvalidDataException("invalid index entry");
                    }
                }
                else if(k=="flags") {
                    foreach(object item in List(v)) {
                        var e=Map(item);
                        EvidencePath(e["path"]);
                        string flag=(string)e["flag"];
                        if(flag.Length!=1||!Char.IsLetter(flag[0]))throw new InvalidDataException("invalid flag");
                    }
                }
                else if(k=="untracked") {
                    foreach(object p in List(v))EvidencePath(p);
                }
                else if(k=="status"||k=="staged")Nul(Dec(v));
                else if(k=="administration") {
                    var a=Map(v);
                    Keys(a,"gitfile","location","gitdir","gitdir_identity","commondir","common_pointer","common_identity");
                    foreach(string n in new[] {
                        "gitdir","commondir"
                    }
                    )if(!AbsoluteEvidence(Text(a[n])))throw new InvalidDataException("invalid administration path");
                    foreach(string n in new[] {
                        "gitfile","common_pointer"
                    }
                    )if(a[n]!=null)Dec(a[n]);
                    foreach(string n in new[] {
                        "location","gitdir_identity","common_identity"
                    }
                    ) {
                        var id=List(a[n]);
                        if(id.Count!=2||id.Any(x=>Integer(x)<0))throw new InvalidDataException("invalid file identity");
                    }
                }
                else if(k.StartsWith("path:",StringComparison.Ordinal)) {
                    string path=EvidencePath(k.Substring(5));
                    var o=Map(v);
                    if(o.ContainsKey("submodule")) {
                        Keys(o,"submodule");
                        ValidateSub(o["submodule"],path);
                    }
                    else Observation(o);
                }
                else throw new InvalidDataException("unknown observation field");
            }
            if((bool)r["complete"]) {
                var paths=Set(List(f["index"]).Select(e=>(string)Map(e)["path"]).Union(List(f["untracked"]).Cast<string>()));
                if(!Set(paths.Select(p=>"path:"+p)).SetEquals(f.Keys.Where(k=>k.StartsWith("path:",StringComparison.Ordinal))))throw new InvalidDataException("incomplete path inventory");
            }
            return r;
        }
        static HashSet<string> StatusPaths(object value) {
            var paths=Set(new string[0]);
            var rows=Nul(Dec(value));
            for(int i=0;
            i<rows.Count;
            i++) {
                string item=rows[i];
                if(item.Length<4||item[2]!=' ')throw new InvalidDataException("invalid status grammar");
                paths.Add(EvidencePath(Enc(item.Substring(3))));
                if(item.Substring(0,2).IndexOfAny(new[] {
                    'R','C'
                }
                )>=0) {
                    if(++i>=rows.Count)throw new InvalidDataException("missing rename source");
                    paths.Add(EvidencePath(Enc(rows[i])));
                }
            }
            return paths;
        }
        static object Preflight(object value) {
            var r=Validate(value);
            if(!(bool)r["complete"])throw new InvalidDataException("preflight capture unavailable");
            var f=Map(r["fields"]);
            var paths=Set(List(f["untracked"]).Select(Text));
            var flags=new Dictionary<string,string>(StringComparer.Ordinal);
            foreach(object item in List(f["flags"])) {
                var e=Map(item);
                flags[(string)e["path"]]=((string)e["flag"]).ToUpperInvariant();
            }
            foreach(object item in List(f["index"])) {
                var e=Map(item);
                if((string)e["mode"]!="160000")continue;
                var l=Map(Map(Map(f["path:"+(string)e["path"]])["submodule"])["location"]);
                string flag;
                flags.TryGetValue((string)e["path"],out flag);
                if((string)l["kind"]!="directory"&&!((string)l["kind"]=="missing"&&flag=="S"))paths.Add(Text(e["path"]));
            }
            paths.UnionWith(StatusPaths(f["status"]));
            var rows=Nul(Dec(f["staged"]));
            for(int i=0;
            i<rows.Count;
            i++) {
                if(!System.Text.RegularExpressions.Regex.IsMatch(rows[i],@"\A:[0-7]{6} [0-7]{6} [0-9a-f]+ [0-9a-f]+ [A-Z]\z")||++i>=rows.Count)throw new InvalidDataException("invalid staged grammar");
                paths.Add(EvidencePath(Enc(rows[i])));
            }
            return D("uncommitted",paths.Count>0,"paths",Sorted(paths).Select(Enc).ToArray(),"status",f["status"],"staged",f["staged"],"limits",Limits);
        }
        static Dictionary<string,object> ReadRecord(string dir,out object identity) {
            string snapshot=System.IO.Path.Combine(dir,"snapshot.json"),diagnostic=System.IO.Path.Combine(dir,"diagnostic.json");
            bool s=Native.Exists(snapshot),d=Native.Exists(diagnostic);
            if(s==d)throw new InvalidDataException("expected exactly one snapshot or diagnostic");
            string path=s?snapshot:diagnostic;
            byte[] data=AdminRead(path,false,268435456);
            var r=Validate(Json.Read(Utf8.GetString(data)));
            if((bool)r["complete"]!=s)throw new InvalidDataException("filename/completeness mismatch");
            identity=D("path",Native.Absolute(path),"sha256",Hash(data));
            return r;
        }
        static object Compare(string before,string after,out int code) {
            var records=new List<Dictionary<string,object>>();
            var identities=new List<object>();
            var errors=new List<object>();
            foreach(string dir in new[] {
                before,after
            }
            ) {
                try {
                    object id;
                    var r=ReadRecord(dir,out id);
                    records.Add(r);
                    identities.Add(id);
                    errors.AddRange(List(r["errors"]));
                }
                catch(Exception e) {
                    records.Add(null);
                    identities.Add(D("path",Native.Absolute(dir),"unavailable",e.Message));
                    errors.Add(e.Message);
                }
            }
            var diffs=new List<object>();
            var a=records[0];
            var b=records[1];
            if(a!=null&&b!=null) {
                if(!Eq(a["checkout"],b["checkout"]))errors.Add("checkout identity mismatch");
                else {
                    var af=Map(a["fields"]);
                    var bf=Map(b["fields"]);
                    foreach(string key in af.Keys.Intersect(bf.Keys).OrderBy(k=>k,StringComparer.Ordinal))if(!Eq(af[key],bf[key]))diffs.Add(D("field",key,"before",af[key],"after",bf[key]));
                }
            }
            code=diffs.Count>0?1:(a!=null&&b!=null&&(bool)a["complete"]&&(bool)b["complete"]&&errors.Count==0?0:2);
            return D("schema",3,"outcome",code==0?"identical":code==1?"changed":"unavailable","inputs",identities,"differences",diffs,"errors",errors,"limits",Limits);
        }
        static Result GitRead(string directory,string[] args) {
            var allowed=Set(new[] {
                "rev-parse","log","show","diff","merge-base","check-ignore","symbolic-ref","cat-file","worktree","check-ref-format"
            }
            );
            if(args.Length==0||!allowed.Contains(args[0]))throw new InvalidDataException("git-read requires an allowed read-only command");
            string[] unsafeOptions= {
                "--output","--ext-diff","--textconv","--no-index","--remerge-diff","--diff-merges"
            }
            ;
            foreach(string a in args) {
                string key=a.Split('=')[0];
                if(a.StartsWith("--")&&a!="--"&&unsafeOptions.Any(o=>o.StartsWith(key,StringComparison.Ordinal)))throw new InvalidDataException("unsafe git-read option");
            }
            if(new[] {
                "diff","log","show"
            }
            .Contains(args[0]))foreach(string a in args.Skip(1)) {
                int eq=a.IndexOf('=');
                string key=eq<0?a:a.Substring(0,eq),value=eq<0?"":a.Substring(eq+1);
                if(!key.StartsWith("--")||key=="--")continue;
                if("--ignore-submodules".StartsWith(key,StringComparison.Ordinal)) {
                    if(key!="--ignore-submodules"||!new[] {
                        "dirty","all"
                    }
                    .Contains(value))throw new InvalidDataException("ignore-submodules safety override refused");
                }
                else if("--submodule".StartsWith(key,StringComparison.Ordinal)) {
                    if(key!="--submodule"||value!="short")throw new InvalidDataException("submodule safety override refused");
                }
                else if(new[] {
                    "--no-ignore-submodules","--no-submodule"
                }
                .Any(o=>o.StartsWith(key,StringComparison.Ordinal)))throw new InvalidDataException("submodule safety disable refused");
            }
            if(args[0]=="check-ref-format"&&(args.Length!=3||args[1]!="--branch"))throw new InvalidDataException("check-ref-format requires --branch and one name");
            if(args[0]=="cat-file"&&(args.Length!=3||!new[] {
                "-e","-p","-t","-s"
            }
            .Contains(args[1])))throw new InvalidDataException("cat-file requires one object");
            if(args[0]=="worktree"&&!args.Skip(1).SequenceEqual(new[] {
                "list","--porcelain","-z"
            }
            ))throw new InvalidDataException("worktree requires list --porcelain -z");
            if(args[0]=="symbolic-ref"&&(args.Skip(1).Count(a=>!a.StartsWith("-"))!=1||args.Contains("--delete")||args.Contains("-d")))throw new InvalidDataException("symbolic-ref requires one read target");
            string root=Canonical(directory);
            while(!Native.Exists(System.IO.Path.Combine(root,".git"))) {
                string parent=System.IO.Path.GetDirectoryName(root);
                if(String.IsNullOrEmpty(parent)||parent==root)throw new IOException("no containing checkout");
                root=parent;
            }
            if(args[0]=="diff") {
                bool operands=false;
                foreach(string a in args.Skip(1)) {
                    if(a=="--") {
                        operands=true;
                        continue;
                    }
                    if(!operands&&a.StartsWith("-"))continue;
                    string joined=System.IO.Path.GetFullPath(System.IO.Path.Combine(root,a));
                    if(!joined.Equals(root,StringComparison.OrdinalIgnoreCase)&&!joined.StartsWith(root.TrimEnd('\\')+"\\",StringComparison.OrdinalIgnoreCase))
                        throw new IOException("git-read diff refuses lexical outside-checkout paths");
                    if(!Inside(joined,root))throw new IOException("git-read diff refuses outside-checkout paths");
                }
            }
            var vector=args.ToList();
            if(new[] {
                "diff","log","show"
            }
            .Contains(args[0]))vector.InsertRange(1,new[] {
                "--no-ext-diff","--no-textconv","--ignore-submodules=dirty","--submodule=short"
            }
            );
            using(var view=new View(root)) {
                if(args[0]=="worktree") {
                    if(!System.IO.Path.GetFileName(view.Common).Equals(".git",StringComparison.OrdinalIgnoreCase))throw new IOException("worktree listing needs ordinary main .git directory");
                    string source=System.IO.Path.Combine(view.Common,"worktrees");
                    if(Native.Exists(source))using(var n=Native.Open(source,true,false,true)) {
                        foreach(string name in n.Names()) {
                            foreach(string leaf in new[] {
                                "HEAD","gitdir","locked"
                            }
                            )view.Copy(source,name+"/"+leaf,leaf=="locked");
                            string dest=System.IO.Path.Combine(view.Private,"worktrees",name);
                            Directory.CreateDirectory(dest);
                            foreach(string leaf in new[] {
                                "HEAD","gitdir","locked"
                            }
                            ) {
                                string copied=System.IO.Path.Combine(view.Private,name,leaf);
                                if(File.Exists(copied))File.Move(copied,System.IO.Path.Combine(dest,leaf));
                            }
                            Directory.Delete(System.IO.Path.Combine(view.Private,name));
                            File.WriteAllText(System.IO.Path.Combine(dest,"commondir"),"../..\n",Utf8);
                        }
                    }
                    view.Copy(view.Common,"HEAD",false);
                    var result=view.Call(vector.ToArray(),null,0,1);
                    var rows=Nul(result.Stdout);
                    if(rows.Count==0||!rows[0].StartsWith("worktree "))throw new IOException("invalid worktree inventory");
                    rows[0]="worktree "+System.IO.Path.GetDirectoryName(view.Common).Replace('\\','/');
                    result.Stdout=Utf8.GetBytes(String.Join("\0",rows)+"\0");
                    return result;
                }
                var r=view.Call(vector.ToArray(),null,args[0]=="check-ref-format"?new[] {
                    0,1,128
                }
                :new[] {
                    0,1
                }
                );
                if(args[0]=="check-ref-format"&&r.ExitCode==128)r.ExitCode=1;
                return r;
            }
        }
        static void Publish(string directory,string name,object value) {
            using(var dir=Native.Open(directory,true,false,true)) {
                string temp=System.IO.Path.Combine(directory,".publish-"+Guid.NewGuid().ToString("N"));
                try {
                    using(var file=new FileStream(temp,FileMode.CreateNew,FileAccess.Write,FileShare.None)) {
                        byte[] bytes=Utf8.GetBytes(Json.Write(value)+"\n");
                        file.Write(bytes,0,bytes.Length);
                        file.Flush(true);
                    }
                    File.Move(temp,System.IO.Path.Combine(directory,name));
                }
                finally {
                    if(File.Exists(temp))File.Delete(temp);
                }
            }
        }
        static void ProtectOutput(string output,object record) {
            var r=Map(record);
            Outside(output,new[] {
                Text(r["checkout"])
            }
            );
            var f=Map(r["fields"]);
            if(f.ContainsKey("administration")) {
                var a=Map(f["administration"]);
                Outside(output,new[] {
                    Text(a["gitdir"]),Text(a["commondir"])
                }
                );
            }
        }
        static Dictionary<string,string> Options(string[] args,string[] required) {
            var d=new Dictionary<string,string>(StringComparer.Ordinal);
            for(int i=1;
            i<args.Length;
            i+=2) {
                if(i+1==args.Length||!required.Contains(args[i])||d.ContainsKey(args[i]))throw new InvalidDataException("invalid command options");
                d.Add(args[i],Native.Absolute(args[i+1]));
            }
            if(!Set(d.Keys).SetEquals(required))throw new InvalidDataException("missing command option");
            return d;
        }
        public static string[] DecodeEnvelope(string[] args) {
            if(args.Length==0||args[0]!="--argv-file")return args;
            if(args.Length!=2)throw new InvalidDataException("--argv-file requires exactly two process tokens");
            string file=Native.Absolute(args[1]),parent=System.IO.Path.GetDirectoryName(file),temp=Canonical(System.IO.Path.GetTempPath());
            Native.PrivateAcl(temp,true);
            if(!System.IO.Path.GetDirectoryName(parent).Equals(temp,StringComparison.OrdinalIgnoreCase)||!System.IO.Path.GetFileName(parent).StartsWith("checkout-state-request-",StringComparison.Ordinal))throw new IOException("argv request must be directly under validated native user temp root");
            using(var root=Native.Open(temp,true,false,true))using(var dir=Native.Open(parent,true,false,true))using(var input=Native.Open(file,false,true,true)) {
                Native.PrivateAcl(parent,true);
                Native.PrivateAcl(file,false);
                var a=List(Json.Read(Utf8.GetString(input.Bytes(8388608))));
                if(a.Any(x=>!(x is string)))throw new InvalidDataException("argv envelope requires a JSON string array");
                return a.Cast<string>().ToArray();
            }
        }
        public static Result InvokeJson(string powershell,string script,string argvJson,string[] protectedRoots) {
            var argumentArray=List(Json.Read(argvJson));
            if(argumentArray.Any(x=>!(x is string)))throw new InvalidDataException("argv requires a JSON string array");
            powershell=Native.Absolute(powershell);
            script=Native.Absolute(script);
            string temp=Canonical(System.IO.Path.GetTempPath());
            Native.PrivateAcl(temp,true);
            Outside(temp,protectedRoots??new string[0]);
            string request=System.IO.Path.Combine(temp,"checkout-state-request-"+Guid.NewGuid().ToString("N"));
            Native.MakePrivate(request);
            try {
                using(var dir=Native.Open(request,true,false,true)) {
                    Native.PrivateAcl(request,true);
                    string file=System.IO.Path.Combine(request,"argv.json");
                    using(var stream=new FileStream(file,FileMode.CreateNew,FileAccess.Write,FileShare.None)) {
                        byte[] data=Utf8.GetBytes(argvJson);
                        stream.Write(data,0,data.Length);
                        stream.Flush(true);
                    }
                    Native.PrivateAcl(file,false);
                    return Run(powershell,new[] {
                        "-NoProfile","-ExecutionPolicy","Bypass","-File",script,"--argv-file",file
                    }
                    ,temp,null,null,120000);
                }
            }
            finally {
                if(Directory.Exists(request))Directory.Delete(request,true);
            }
        }
        public static int Dispatch(string[] processArgs) {
            try {
                string[] args=DecodeEnvelope(processArgs);
                if(args.Length==0)throw new InvalidDataException("command required");
                if(args[0]=="resolve") {
                    if(args.Length!=1)throw new InvalidDataException("resolve takes no arguments");
                    Output(Json.Write(D("argv",new[] {
                        Process.GetCurrentProcess().MainModule.FileName,"-NoProfile","-ExecutionPolicy","Bypass","-File",OwnerScript
                    }
                    ,"os","Windows","engine","dotnet","version",Environment.Version.ToString(),"file_identity","FILE_ID_INFO unsigned volume64/file128"))+"\n");
                    return 0;
                }
                if(args[0]=="preflight") {
                    var o=Options(args,new[] {
                        "--capture-dir"
                    }
                    );
                    object identity;
                    Output(Json.Write(Preflight(ReadRecord(o["--capture-dir"],out identity)))+"\n");
                    return 0;
                }
                if(args[0]=="git-read") {
                    if(args.Length<4||args[1]!="--checkout")throw new InvalidDataException("git-read requires --checkout ABS -- COMMAND");
                    int skip=args.Length>3&&args[3]=="--"?4:3;
                    var r=GitRead(args[2],args.Skip(skip).ToArray());
                    Console.OpenStandardOutput().Write(r.Stdout,0,r.Stdout.Length);
                    return r.ExitCode;
                }
                if(args[0]=="capture") {
                    var o=Options(args,new[] {
                        "--checkout","--output-dir"
                    }
                    );
                    string output=o["--output-dir"];
                    Outside(output,ProtectedRoots(o["--checkout"]));
                    var r=Capture(o["--checkout"]);
                    ProtectOutput(output,r);
                    Native.MakePrivate(output);
                    Publish(output,(bool)r["complete"]?"snapshot.json":"diagnostic.json",r);
                    return (bool)r["complete"]?0:2;
                }
                if(args[0]=="compare") {
                    var o=Options(args,new[] {
                        "--before","--after","--output-dir"
                    }
                    );
                    foreach(string input in new[] {
                        o["--before"],o["--after"]
                    }
                    ) {
                        object id;
                        Dictionary<string,object> r;
                        try {
                            r=ReadRecord(input,out id);
                        }
                        catch {
                            continue;
                        }
                        ProtectOutput(o["--output-dir"],r);
                    }
                    Native.MakePrivate(o["--output-dir"]);
                    int code;
                    object result=Compare(o["--before"],o["--after"],out code);
                    Publish(o["--output-dir"],"result.json",result);
                    return code;
                }
                throw new InvalidDataException("unknown checkout-state command");
            }
            catch(Exception e) {
                byte[] b=Utf8.GetBytes("state verification unavailable: "+e.GetType().Name+": "+e.Message+"\n");
                Console.OpenStandardError().Write(b,0,b.Length);
                return 2;
            }
        }
        static void Output(string s) {
            byte[] b=Utf8.GetBytes(s);
            Console.OpenStandardOutput().Write(b,0,b.Length);
        }
    }
}
