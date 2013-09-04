$script:APPID = "31FE815731F73CBC656686FDD7BFA680448517B4";
$script:APPNAME = "PoshBing";
$script:BINGURL = "http://api.search.live.net/xml.aspx";
$script:COMMONFIELDHASH = @{
  "Version" = "2.0";
  "Market" = "en-us";
  "Adult" = "Moderate";
  "Options" = "EnableHighlighting";
};
$script:CODETOLANG = @{
  "Ar" = "Arabic";
  "zh-CHS" = "Simplified Chinese";
  "zh-CHT" = "Traditional Chinese";
  "Nl" = "Dutch";
  "En" = "English";
  "Fr" = "French";
  "De" = "German";
  "It" = "Italian";
  "Ja" = "Japanese";
  "Ko" = "Korean";
  "Pl" = "Polish";
  "Pt" = "Portuguese";
  "Ru" = "Russian";
  "Es" = "Spanish";
};
$script:LANGTOCODE = @{
  "Arabic" = "Ar";
  "Simplified Chinese" = "zh-CHS";
  "Traditional Chinese" = "zh-CHT";
  "Dutch" = "Nl";
  "English" = "En";
  "French" = "Fr";
  "German" = "De";
  "Italian" = "It";
  "Japanese" = "Ja";
  "Korean" = "Ko";
  "Polish" = "Pl";
  "Portuguese" = "Pt";
  "Russian" = "Ru";
  "Spanish" = "Es";
};
$script:SOURCETYPES = @{
  "Image" = $true;
  "InstantAnswer" = $true;
  "News" = $true;
  "MobileWeb" = $true;
  "Phonebook" = $true;
  "RelatedSearch" = $true;
  "Spell" = $true;
  "Web" = $true;
  "Translation" = $true;
  "Video" = $true;
};
$script:PHONEBOOKS = @{
  "YP" = $true;
  "WP" = $true;
};
$script:PHONEBOOKSORTBYTYPES = @{
  "Default" = $true;
  "Distance" = $true;
  "Relevance" = $true;
};
$script:IMAGEFILTERS = @{
  "Size:Small" = $true;
  "Size:Medium" = $true;
  "Size:Large" = $true;
  "Size:Height" = $true;
  "Size:Width" = $true;
  "Aspect:Square" = $true;
  "Aspect:Wide" = $true;
  "Aspect:Tall" = $true;
  "Color:Color" = $true;
  "Color:Monochrome" = $true;
  "Style:Photo" = $true;
  "Style:Graphics" = $true;
  "Face:Face" = $true;
  "Face:Portrait" = $true;
  "Face:Other" = $true;
};

$script:VIDEOFILTERS = @{
  "Duration:Short" = $true;
  "Duration:Medium" = $true;
  "Duration:Long" = $true;
  "Aspect:Standard" = $true;
  "Aspect:Widescreen" = $true;
  "Resolution:Low" = $true;
  "Resolution:Medium" = $true;
  "Resolution:High" = $true;
};

#============================================================================
# Shared Functions
#============================================================================
function Get-BingUrl()
{
  $script:BINGURL;
}

#----------------------------------------------------------------------------
# function Get-CommonFieldHash
#----------------------------------------------------------------------------
function Get-CommonFieldHash()
{
  $script:COMMONFIELDHASH;
}

#----------------------------------------------------------------------------
# function Set-BingAppId
#----------------------------------------------------------------------------
function Set-BingAppId()
{
  param([string]$appid = $null);
  if ( $appid )
  {
    $script:APPID = $appid;
  }
}

#----------------------------------------------------------------------------
# function Get-BingAppId
#----------------------------------------------------------------------------
function Get-BingAppId()
{
  if ( $null -eq $APPID )
  {
    trap { Write-Error "ERROR: You must enter your Bing AppId for PoshBing to work!"; continue; }
  }
  $script:APPID;
}

#----------------------------------------------------------------------------
# function Get-BingAppName
#----------------------------------------------------------------------------
function Get-BingAppName()
{
  $script:APPNAME;
}

#----------------------------------------------------------------------------
# function Execute-HTTPGetCommand
#----------------------------------------------------------------------------
function Execute-HTTPGetCommand()
{
  param([string] $url = $null);
  if ( $url )
  {
    $request = [System.Net.HttpWebRequest]::Create($url);
    $request.UserAgent = Get-BingAppName;
    $response = $request.GetResponse();
    $rs = $response.GetResponseStream();
    [System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs;
    $sr.ReadToEnd();
  }
}

#============================================================================
# Core Bing Functionality
#============================================================================
function Get-Bing()
{
  param(
    [string]$query,
    [string]$sources,
    [hashtable]$options,
    [hashtable]$common = $script:COMMONFIELDHASH
  );
  
  $xml = $null;
  if ( ! $(Get-BingAppId) )
  {
    Write-Host "ERROR: You must first call the Set-BingAppId function with a valid AppId";
  }
  elseif ( $query -and $sources )
  {
    $url = Get-BingUrl;
    
    # Common request fields (required)
    $url += "?AppId=$(Get-BingAppId)";
    $url += "&Query=$query";
    $url += "&Sources=$sources";
    
    # Common request fields (optional)
    if ( $common )
    {
      foreach ($key in $common.keys)
      {
        $val = $common[$key];
        $url += "&${key}=${val}";
      }
    }
    
    if ( $options )
    {
      foreach ($key in $options.keys)
      {
        $val = $options[$key];
        $url += "&${key}=${val}";
      }
    }
    
    $xml = Execute-HTTPGetCommand $url;
  }
  $xml;
}

#----------------------------------------------------------------------------
# Process-BingResponse
#----------------------------------------------------------------------------
function Process-BingResponse()
{
  param([xml]$xml = $null);
  if ( $xml )
  {
    if ( $xml.SearchResponse.Errors )
    {
      $xml.SearchResponse.Errors.Error
    } 
    elseif ( $xml.SearchResponse.Query.SearchTerms ) 
    {
      $xml.SearchResponse | Get-Member -Type Properties | 
      Where-Object { $xml.SearchResponse.$($_.Name) -is [Xml.XmlElement] } |
      ForEach-Object { 
         $name = $_.Name
         if($xml.SearchResponse.$name.Results) {
            Get-Member -input $xml.SearchResponse.$name.Results -type Property | 
            ForEach-Object { $xml.SearchResponse.$name.Results.$($_.Name) } | 
            Add-Member -Passthru -Name "Query" -Type NoteProperty -Value $xml.SearchResponse.Query.SearchTerms |
            Add-Member -Passthru -Name "SourceType" -Type NoteProperty -Value $_.Name;
         } 
      }
    }
  }
}

#============================================================================
# Image
#============================================================================
function Get-BingImage()
{
  param(
    [string]$query = $null,
    [int]$count = 10,
    [int]$offset = 0,
    [string]$filters = $null,
    [switch]$raw
  );
  
  $options = @{
    "Image.Count" = $count;
    "Image.Offset" = $offset
  };
  
  if ( $filters )
  {
    $filtersA = $filters.Split("+, ");
    foreach ($filter in $filtersA)
    {
      $valid = $false;
      foreach ($key in $script:IMAGEFILTERS.keys)
      {
        if ($filter.ToLower().StartsWith($key.ToLower()) )
        {
          $valid = $true;
        }
      }
      if ( !$valid )
      {
        Write-Host "ERROR: Invalid Image Filter:  Valid filters are:"
        foreach ($key in $script:IMAGEFILTERS.keys)
        {
          Write-Host $key;
        }
        return;
      }
    }
    $jfilters = [string]::Join('+', $filtersA);
    $options.Add("Image.Filters", $jfilters)
  }
  
  $xml = Get-Bing -query $query -sources "Image" -options $options;
  if ( $raw )
  {
    $xml
  }
  else
  {
    Process-BingResponse $xml;
  }
}


#============================================================================
# InstantAnswer (encarta 2.0, flightstatus 2.2)
#============================================================================
function Get-BingInstantAnswer()
{
  param(
    [string]$query = $null,
    [switch]$raw
  );
  
  $common = Get-CommonFieldHash;
  $common["Version"] = "2.2";
  
  $xml = Get-Bing -query $query -sources "InstantAnswer" -common $common;
  if ( $raw )
  {
    $xml
  }
  else
  {
    Process-BingResponse $xml;
  }
}

#============================================================================
# News
#============================================================================
function Get-BingNews()
{
  param(
    [string]$query = $null,
    [string]$offset = 0,
    [string]$locationoverride = $null,
    [string]$category = $null,
    [string]$sortby = $null,
    [switch]$raw
  );
  
  $options = @{
    "News.Offset" = $offset;
  };
  if ( $news_locationoverride )
  {
    $options.Add("News.LocationOverride", $locationoverride)
  };
  if ( $category ) { $options.Add("News.Category", $category) };
  if ( $sortby ) { $options.Add("News.SortBy", $sortby) };
  
  $xml = Get-Bing -query $query -sources "News" -options $options;
  if ( $raw )
  {
    $xml
  }
  else
  {
    Process-BingResponse $xml;
  }
}

#============================================================================
# MobileWeb (2.1)
#============================================================================
function Get-BingMobileWeb()
{
  param(
    [string]$query = $null,
    [int]$count = 2,
    [int]$offset = 0,
    [string]$options = "DisableHostCollapsing+DisableQueryAlterations",
    [switch]$raw = $false
  );
  
  $common = Get-CommonFieldHash;
  $common["Version"] = "2.1";

  $opts = @{
    "MobileWeb.Count" = $count;
    "MobileWeb.Offset" = $offset;
    "MobileWeb.Options" = $options;
  };
  
  $xml = Get-Bing -query $query -sources "MobileWeb" `
    -options $opts -common $common;
  if ( $raw )
  {
    $xml
  }
  else
  {
    Process-BingResponse $xml;
  }
}

#============================================================================
# Phonebook
#============================================================================
function Get-BingPhonebook()
{
  param(
    [string]$query = $null,
    [int]$count = 10,
    [int]$offset = 0,
    [string]$filetype = "YP",
    [string]$sortby = "Distance",
    [switch]$raw
  );
  
  $options = @{
    "Phonebook.Count" = $count;
    "Phonebook.Offset" = $offset;
    "Phonebook.FileType" = $filetype;
    "Phonebook.SortBy" = $sortby
  };
  
  if ( ! $script:PHONEBOOKS[$filetype] )
  {
    Write-Host "ERROR: Invalid Phonebook type.  Please use one or more of:"
    foreach ($key in $script:PHONEBOOKS.keys)
    {
      Write-Host $key;
    }
    return;
  }
  if ( ! $script:PHONEBOOKSORTBYTYPES[$sortby] )
  {
    Write-Host "ERROR: Invalid Phonebook Sortby Type.  Please use one or more of:"
    foreach ($key in $script:PHONEBOOKSORTBYTYPES.keys)
    {
      Write-Host $key;
    }
    return;
  }
  
  $xml = Get-Bing -query $query -sources "Phonebook" -options $options;
  if ( $raw )
  {
    $xml
  }
  else
  {
    Process-BingResponse $xml;
  }
}

#============================================================================
# RelatedSearch
#============================================================================
function Get-BingRelatedSearch()
{
  param(
    [string]$query = $null,
    [switch]$raw
  );
  
  $xml = Get-Bing -query $query -sources "RelatedSearch";
  if ( $raw )
  {
    $xml
  }
  else
  {
    Process-BingResponse $xml;
  }
}

#============================================================================
# Spell
#============================================================================
function Get-BingSpell()
{
  param(
    [string]$query = $null,
    [switch]$raw = $false
  );
  
  $xml = Get-Bing -query $query -sources "Spell";
  if ( $raw )
  {
    $xml
  }
  else
  {
    Process-BingResponse $xml;
  }
}

#============================================================================
# Web
#============================================================================
function Get-BingWeb()
{
  param(
    [string]$query = $null,
    [int]$count = 10,
    [int]$offset = 0,
    [string]$options = "DisableHostCollapsing+DisableQueryAlterations",
    [switch]$raw
  );
  
  $opts = @{
    "Web.Count" = $count;
    "Web.Offset" = $offset;
    "Web.Options" = $options;
  };
  
  $xml = Get-Bing -query $query -sources "Web" -options $opts;
  if ( $raw )
  {
    $xml
  }
  else
  {
    Process-BingResponse $xml;
  }
}

#============================================================================
# Translation (2.2)
#============================================================================
function Get-BingTranslation()
{
  param(
    [string]$query = $null,
    [string]$from = "en",
    [string]$to = "es",
    [switch]$raw
  );
  
  $common = Get-CommonFieldHash;
  $common["Version"] = "2.2";
  
  if ( ! $script:CODETOLANG[$from] )
  {
    Write-Host "ERROR: from language is not valid.  It must be one of:"
    foreach ($key in $script:CODETOLANG.keys)
    {
      Write-KeyValue $key $script:CODETOLANG[$key];
    }
    return;
  }
  if ( ! $script:CODETOLANG[$to] )
  {
    Write-Host "ERROR: to language is not valid.  It must be one of:"
    foreach ($key in $script:CODETOLANG.keys)
    {
      Write-KeyValue $key $script:CODETOLANG[$key];
    }
    return;
  }
  
  $options = @{
    "Translation.SourceLanguage" = $from;
    "Translation.TargetLanguage" = $to;
  };
  
  $xml = Get-Bing -query $query -sources "Translation" `
    -options $options -common $common;
  if ( $raw )
  {
    $xml
  }
  else
  {
    Process-BingResponse $xml;
  }
}

#============================================================================
# Video (2.1)
#============================================================================
function Get-BingVideo()
{
  param(
    [string]$query = $null,
    [int]$count = 2,
    [int]$offset = 0,
    [string]$filters = $null,
    [switch]$raw
  );
  
  $common = Get-CommonFieldHash;
  $common["Version"] = "2.1";
  
  $options = @{
    "Video.Count" = $count;
    "Video.Offset" = $offset;
  };
  
  if ( $filters )
  {
    $filtersA = $filters.Split("+, ");
    foreach ($filter in $filtersA)
    {
      $valid = $false;
      foreach ($key in $script:VIDEOFILTERS.keys)
      {
        if ($filter.ToLower().StartsWith($key.ToLower()) )
        {
          $valid = $true;
        }
      }
      if ( !$valid )
      {
        Write-Host "ERROR: Invalid Video Filter:  Valid filters are:"
        foreach ($key in $script:VIDEOFILTERS.keys)
        {
          Write-Host $key;
        }
        return;
      }
    }
    $jfilters = [string]::Join('+', $filtersA);
    $options.Add("Video.Filters", $jfilters)
  }
  
  
  
  $xml = Get-Bing -query $query -sources "Video" `
    -options $options -common $common;
  if ( $raw )
  {
    $xml
  }
  else
  {
    Process-BingResponse $xml;
  }
}

#============================================================================
# Multiple (2.0)
#============================================================================
function Get-BingMultiple()
{
  param(
    [string]$query = $null,
    [string]$types = "Web+RelatedSearch",
    [switch]$raw
  );
  
  # Validate Source Types
  $valid = $true;
  $stypes = $types.Split("+, ");
  foreach ($type in $stypes)
  {
    if ( ! $script:SOURCETYPES[$type] )
    {
      $valid = $false
    }
  }
  if ( $valid )
  {
    $s_types = [string]::Join('+', $stypes);
    $xml = Get-Bing -query $query -sources $s_types;
    if ( $raw )
    {
      $xml
    }
    else
    {
      Process-BingResponse $xml;
    }
  }
  else
  {
    Write-Host "ERROR: Invalid Source Type.  Please use one or more of:"
    foreach ($key in $script:SOURCETYPES.keys)
    {
      Write-Host $key;
    }
  }
}

#Export-ModuleMember Get-BingImage,Get-BingInstantAnswer,Get-BingMobileWeb,`
#  Get-BingNews,Get-BingPhonebook,Get-BingRelatedSearch,Get-BingSpell,`
#  Get-BingTranslation,Get-BingVideo,Get-BingWeb,Get-BingMultiple,Set-BingAppId

#Get-BingImage "Navinet";
#Get-BingInstantAnswer "Calories in a squirrel";
#Get-BingInstantAnswer "WN43";
#Get-BingNews "Navinet";
#Get-BingMobileWeb "microsoft";
#Get-BingPhonebook "microsoft";
#Get-BingRelatedSearch "games";
#Get-BingSpell "Mipselling wrods is a common ocurrence";
#Get-BingWeb "Sriram Devadas";
#Get-BingTranslation "How are you doing today?" -to "Pl";
#Get-BingVideo "xbox site:microsoft.com";
#Get-BingMultiple "microsoft" "Web,Video";

