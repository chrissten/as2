param(
    $FileName,
    $ContentType,
    $SigningCert,
    $SigningCertPwd,
    $EncryptionCert,
    $encryptionAlgorithm = "3DES"
)

Add-Type -Path "C:\projects\Internal_NonProduct\AS2Client\bin\Debug\System.Security.Cryptography.Pkcs.dll"
#Add-Type -AssemblyName "System.Security.Cryptography.X509Certificates"
Add-Type -AssemblyName "System.Security"

function Concat-MultipleByteArrays {
    param (
        [Parameter(Mandatory=$true)]
        [byte[][]]$byteArrays
    )

    # Calculate the total length required for the combined array
    $totalLength = 0
    foreach ($array in $byteArrays) {
        $totalLength += $array.Length
    }

    # Create the combined array with the calculated total length
    $combinedArray = New-Object byte[] $totalLength

    # Copy each array into the combined array at the correct position
    $currentPosition = 0
    foreach ($array in $byteArrays) {
        [Array]::Copy($array, 0, $combinedArray, $currentPosition, $array.Length)
        $currentPosition += $array.Length
    }

    # Return the combined array
    return $combinedArray
}

function Get-MIMEHeader($ContentType,$Encoding,$Disposition){
    $Out = "";

    $Out = "Content-Type: $($ContentType)$([System.Environment]::NewLine)"
    if (![String]::IsNullOrEmpty($Encoding)){
        $Out = "$($Out)Content-Transfer-Encoding: $($Encoding)$([System.Environment]::NewLine)"
    }

    if (![String]::IsNullOrEmpty($Disposition)){
        $Out = $Out + "Content-Disposition: " + $Disposition + [System.Environment]::NewLine
    }

    $Out = $Out + [System.Environment]::NewLine

    return $Out;
}

$BytesToSend = [System.IO.File]::ReadAllBytes($FileName)
#$SourceFileFI = [System.IO.FileInfo]$SourceFile

#Create Message
$ContenTypeHeaderBytes = [System.Text.Encoding]::ASCII.GetBytes((Get-MIMEHeader -ContentType $ContentType -Encoding "binary"))
$Message = Concat-MultipleByteArrays($ContenTypeHeaderBytes,$BytesToSend)
[System.IO.File]::WriteAllBytes("A:\PS_Line63.txt",$Message)

#Sign
$Boundary = "_" + [System.Guid]::NewGuid().ToString("N") + "_"
$ContentType = "multipart/signed; protocol=`"application/pkcs7-signature`"; micalg=`"sha1`"; boundary=`"$($Boundary)`"";
$bBoundary = [System.Text.Encoding]::ASCII.GetBytes([System.Environment]::NewLine + "--" + $Boundary + [System.Environment]::NewLine);
$bSignatureHeader = [System.Text.Encoding]::ASCII.GetBytes((Get-MIMEHeader -ContentType  "application/pkcs7-signature; name=`"smime.p7s`"" -Encoding "base64" -Disposition "attachment; filename=smime.p7s"))

##Encode Signature
if(![String]::IsNullOrEmpty($SigningCertPwd)){
    $signingCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($SigningCert, $SigningCertPwd);
}
else{
    $signingCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($SigningCert);
}
$contentInfo = [System.Security.Cryptography.Pkcs.ContentInfo]::new($Message);
$signedCms = [System.Security.Cryptography.Pkcs.SignedCms]::new($contentInfo, $true);
$cmsSigner = [System.Security.Cryptography.Pkcs.CmsSigner]::new($signingCert);
$signedCms.ComputeSignature($cmsSigner);
$bSignature = $signedCms.Encode();

$sig = [System.Convert]::ToBase64String($bSignature) + "`r`n`r`n";
$bSignature = [System.Text.Encoding]::ASCII.GetBytes($sig);

$bFinalFooter = [System.Text.Encoding]::ASCII.GetBytes("--" + $Boundary + "--" + [System.Environment]::NewLine);

$bInPKCS7 = Concat-MultipleByteArrays($bBoundary, $Message, $bBoundary,
    $bSignatureHeader, $bSignature, $bFinalFooter);

$signedContentTypeHeader = [System.Text.Encoding]::ASCII.GetBytes("Content-Type: " + $ContentType + [System.Environment]::NewLine);
$contentWithContentTypeHeaderAdded = Concat-MultipleByteArrays($signedContentTypeHeader, $bInPKCS7);

#content = AS2Encryption.Encrypt($contentWithContentTypeHeaderAdded, $EncryptionCert, "3DES");

$encryptionCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($EncryptionCert);
$envelopedCms = [System.Security.Cryptography.Pkcs.EnvelopedCms]::new(
    [System.Security.Cryptography.Pkcs.ContentInfo]::new($contentWithContentTypeHeaderAdded),
    ([System.Security.Cryptography.Pkcs.AlgorithmIdentifier]::new([System.Security.Cryptography.Oid]::new($encryptionAlgorithm)))); 
$recipient = [System.Security.Cryptography.Pkcs.CmsRecipient]::new([System.Security.Cryptography.Pkcs.SubjectIdentifierType]::IssuerAndSerialNumber, $encryptionCert);
$envelopedCms.Encrypt($recipient);

return [System.Convert]::ToBase64String($envelopedCms.Encode())

