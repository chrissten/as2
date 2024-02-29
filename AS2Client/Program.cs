using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace WebTestPlugins.AS2Helpers
{
    internal class Program
    {
        static void Main(string[] args)
        {
            AS2Send.SendFile(
                new Uri("http://localhost:11080"),
                "someFile.txt",
                UTF32Encoding.UTF8.GetBytes("Hi mom"),
                "PartnerA_OID",
                "MyCompany_OID",
                new ProxySettings(),
                5000,
                @"C:\projects\OpenSourceProjects\OpenAS2\config\partnera.pfx",
                "",
                @"C:\projects\OpenSourceProjects\OpenAS2\config\mycompany.pub",
                "userID",
                "pWd"
                );
        }
    }
}
