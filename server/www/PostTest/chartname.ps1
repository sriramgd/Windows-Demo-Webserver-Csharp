function simpleEncoding ($valueArray, $labelArray, $size, [switch] $chart3D) {

    $simpleEncoding = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    if ($chart3D) {$chartType = "p3"} else {$chartType ="p"}
    $total = 0
    foreach ($value in $valueArray) {
        $total = $total + $value
    }
    for ($i = 0;$i -lt $valueArray.length;$i++) {
        $relativeValue = ($valueArray[$i] / $total)*62
        $relativeValue = [math]::round($relativeValue)
        $encodingValue = $simpleEncoding[$relativeValue]
        $chartData = $chartData + "" + $encodingValue
    }
    $chartLabel = [string]::join("|",$labelArray)
    Write-Output "http://chart.apis.google.com/chart?cht=$chartType&chd=s:$chartdata&chs=$size&chl=$chartLabel"
}

function DownloadAndShowImage ($url) {
    $localfilename = "c:\temp\chart.png"
    $webClient = new-object System.Net.WebClient
    $webClient.Headers.Add("user-agent", "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705;)")
    $Webclient.DownloadFile($url, $localfilename)
} 

if ($args.Length -gt 1) {

	$fname = $args[0]
	$lname = $args[1]

	$firstname = ""
	$lastname = ""

	if (!([string]::IsNullOrEmpty($fname))) {
		$firstname = $fname.split("=")[1]
	}
	if (!([string]::IsNullOrEmpty($lname))) {
		$lastname = $lname.split("=")[1]
	}

    

	write-output "<html><head></head><body><br /><br /><h3>Welcome $firstname $lastname!</h3></body></html>"
	
	$request = [System.Net.WebRequest]::Create("http://google.com")
	$response = $request.GetResponse()
	$requestStream = $response.GetResponseStream()
	$readStream = new-object System.IO.StreamReader $requestStream	
	$db = $readStream.ReadToEnd()
	$readStream.Close()
	$response.Close()
	
	write-output "$db"
}

else {
	
	write-output "<html><head></head><body><br /><br /><h3>Welcome world!</h3></body></html>"

}

