using System;
using System.IO;
using System.Net;
using System.Text;

namespace WebTestPlugins.AS2Helpers
{
    public struct ProxySettings
    {
        public string Name;
        public string Username;
        public string Password;
        public string Domain;
    }

    public class AS2Send
    {
        public static HttpStatusCode SendFile(Uri uri, string filename, byte[] fileData, string from, string to, ProxySettings proxySettings, int timeoutMs, string signingCertFilename, string signingCertPassword, string recipientCertFilename, string httpUserID, string httpPassword)
        {
            if (String.IsNullOrEmpty(filename)) throw new ArgumentNullException("filename");

            if (fileData.Length == 0) throw new ArgumentException("filedata");

            byte[] content = fileData;

            //Initialise the request
            HttpWebRequest http = (HttpWebRequest)WebRequest.Create(uri);

            if (!String.IsNullOrEmpty(proxySettings.Name))
            {
                WebProxy proxy = new WebProxy(proxySettings.Name);

                NetworkCredential proxyCredential = new NetworkCredential();
                proxyCredential.Domain = proxySettings.Domain;
                proxyCredential.UserName = proxySettings.Username;
                proxyCredential.Password = proxySettings.Password;

                proxy.Credentials = proxyCredential;

                http.Proxy = proxy;
            }

            //Define the standard request objects
            http.Method = "POST";

            http.AllowAutoRedirect = true;

            http.KeepAlive = true;

            http.PreAuthenticate = false; //Means there will be two requests sent if Authentication required.
            http.SendChunked = false;

            http.UserAgent = "MY SENDING AGENT";

            //These Headers are common to all transactions
            http.Headers.Add("Mime-Version", "1.0");
            http.Headers.Add("AS2-Version", "1.2");

            http.Headers.Add("AS2-From", from);
            http.Headers.Add("AS2-To", to);
            http.Headers.Add("Subject", filename + " transmission.");
            http.Headers.Add("Message-Id", "<AS2_" + DateTime.Now.ToString("hhmmssddd") + ">");
            http.Timeout = timeoutMs;

            string contentType = (Path.GetExtension(filename) == ".xml") ? "application/xml" : "application/EDIFACT";

            bool encrypt = !string.IsNullOrEmpty(recipientCertFilename);
            bool sign = !string.IsNullOrEmpty(signingCertFilename);

            if (!sign && !encrypt)
            {
                http.Headers.Add("Content-Transfer-Encoding", "binary");
                http.Headers.Add("Content-Disposition", "inline; filename=\"" + filename + "\"");
            }
            if (sign)
            {
                // Wrap the file data with a mime header
                content = AS2MIMEUtilities.CreateMessage(contentType, "binary", "", content);
                System.IO.File.WriteAllBytes(@"A:\CS_Line63.txt", content);

                content = AS2MIMEUtilities.Sign(content, signingCertFilename, signingCertPassword, out contentType);

                http.Headers.Add("EDIINT-Features", "multiple-attachments");

            }
            if (encrypt)
            {
                if (string.IsNullOrEmpty(recipientCertFilename))
                {
                    throw new ArgumentNullException(recipientCertFilename, "if encrytionAlgorithm is specified then recipientCertFilename must be specified");
                }

                byte[] signedContentTypeHeader = System.Text.ASCIIEncoding.ASCII.GetBytes("Content-Type: " + contentType + Environment.NewLine);
                byte[] contentWithContentTypeHeaderAdded = AS2MIMEUtilities.ConcatBytes(signedContentTypeHeader, content);

                content = AS2Encryption.Encrypt(contentWithContentTypeHeaderAdded, recipientCertFilename, EncryptionAlgorithm.DES3);


                contentType = "application/pkcs7-mime; smime-type=enveloped-data; name=\"smime.p7m\"";
            }

            http.ContentType = contentType;
            http.ContentLength = content.Length;
            http.Headers.Add("Authorization", "Basic " + System.Convert.ToBase64String(Encoding.GetEncoding("ISO-8859-1")
                               .GetBytes(httpUserID + ":" + httpPassword)));

            SendWebRequest(http, content);

            return HandleWebResponse(http);
        }

        private static HttpStatusCode HandleWebResponse(HttpWebRequest http)
        {
            HttpWebResponse response = (HttpWebResponse)http.GetResponse();

            response.Close();
            return response.StatusCode;
        }

        private static void SendWebRequest(HttpWebRequest http, byte[] fileData)
        {
            Stream oRequestStream = http.GetRequestStream();
            oRequestStream.Write(fileData, 0, fileData.Length);
            oRequestStream.Flush();
            oRequestStream.Close();
        }
    }
}