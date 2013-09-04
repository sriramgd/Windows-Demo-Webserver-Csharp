. c:\server\www\posttest\bing.ps1
[System.Reflection.Assembly]::LoadWithPartialName("System.web") > $null

if ($args.Length -gt 0) {

	$sterm = $args[0]
	
	$searchname = ""

	if (!([string]::IsNullOrEmpty($sterm))) {
		$searchname = $sterm.split("=")[1]
		$searchname = $searchname.replace("+", " ")
	}

	#write-output $searchname
	
	$output = "<html><head><link type=`"text/css`" rel=`"stylesheet`" media=`"all`" href=`"screen.css`"></head><body>"
	if (!([string]::IsNullOrEmpty($searchname))) {
		if ($sterm.Trim() -ne "") {
			$searchResult = Get-BingWeb $searchname 
			
			$output += "<h2><u>" + $searchname + "</u></h2><br />"
			$searchResult | foreach {        
				$output += "<div><a href=`"" + $_.Url + "`">" + [system.web.httputility]::htmldecode($_.Title) + "</a>"
				$output += "<p>" + [system.web.httputility]::htmldecode($_.Description) + "</p></div>"
				$output += "<hr />"
				}
		}
	}

    $output += "</body></html>"
    write-output $output
	#write-output "<html><head></head><body><br /><br /><h3>Welcome $firstname $lastname!</h3></body></html>"
	
}
else {
	
	write-output "<html><head></head><body><br /><br /><h3></h3></body></html>"
}
