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
	
}

else {
	
	write-output "<html><head></head><body><br /><br /><h3>Welcome world!</h3></body></html>"

}
