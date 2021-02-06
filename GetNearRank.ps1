##########################################################################################
# BeatSaber�ŏ��ʂ��߂��l��PP�𑽂�����������N�Ȃ��擾���ăv���C���X�g�ɂ���
# PPmax < (���g��PP + 20)�̋Ȃ͏��O
##########################################################################################

### �ݒ�

$MY_URL         = "https://scoresaber.com/u/2524699980873617"
$RANK_GET_PAGES = 1..3
$RANK_BASE_URL  = "https://scoresaber.com/global/{rank}&country=jp"
$GET_RANK_RANGE = 3    # �O�㉽�ʂ̐l����擾���邩
$PP_FILTER      = 20   # ���l�����g��PP��肱��ȏ㑽��PP������Ă���Ȃ��o��

### ���C��

function Run-Main() {
	# ���g���ʂ̑O��url�擾�֐�
	$urlList = Get-UrlList $MY_URL $RANK_BASE_URL $RANK_GET_PAGES $GET_RANK_RANGE

	# �ő�pp���X�g�擾
	$maxPpList = @{}

	$urlList | %{ $url = $_
		$ppList = Get-PpList($url)
		$ppList | %{ $ppItem = $_
			$itemKey = $ppItem.id.ToString() +  $ppItem.name
			if ($maxPpList.ContainsKey($itemKey)) {
				$maxPpList[$itemKey].pp = [Math]::Max($maxPpList[$itemKey].pp, $ppItem.pp)
			} else {
				$maxPpList.Add($itemKey, $ppItem)
			}
		}
	}

	# PP����ǉ��ippDiff�����l��pp�Ɠ����B���g�ɑ��݂�����̂̂ݍ��ɏ��������j
	$myPpList = @()
	1..3 | %{ $page = $_
		$myPpList += Get-PpList($MY_URL + "&page=$($page)&sort=1")
	}
	
	$myPpList | %{ $ppItem = $_
		$itemKey = $ppItem.id.ToString() +  $ppItem.name
		if ($maxPpList.ContainsKey($itemKey)) {
			$maxPpList[$itemKey].ppDiff = ($maxPpList[$itemKey].pp - $ppItem.pp)
		}
	}

	# ���ʏo��
	$outList = $maxPpList.Values | ? { $_.ppDiff -gt $PP_FILTER } | sort -desc ppDiff

	$outList | ConvertTo-Csv > csv.txt
	
$playlist =
@"
{
"playlistTitle":"NearRanked{date}",
"songs":[
{song_id_list}
],
"playlistAuthor":"HOGE_PLAYLIST_AUTHOR"
}
"@
	
	$playlist = $playlist -replace "{date}", (date -format "yyyyMMdd")
	$playlist = $playlist -replace "{song_id_list}", (($outList | %{ '{"hash":"' + $_.id + '"}' }) -join ",`n")
	
	$playlist > playlist.bplist
}


### ���g���ʂ̑O��url�擾�֐�

function Get-UrlList($myUrl, $rankBaseUrl, $rankGetPages, $getRankRange) {
	$allList = @()
	
	$rankGetPages | %{ $page = $_
		$rankUrl = $rankBaseUrl -replace "{rank}", $page
		
		$w = Invoke-WebRequest $rankUrl
		
		$el = $w.ParsedHtml.querySelectorAll("table.ranking td.rank")
		$rankList = 0..($el.length-1) | % { [int]($el[$_].innerText -replace "#", "") }
		
		$el = $w.ParsedHtml.querySelectorAll("table.ranking td.player a")
		$urlList = 0..($el.length-1) | % { $el[$_].href -replace "about:/", "https://scoresaber.com/" }
		
		$list = 0..($rankList.Count-1) | %{ [PSCustomObject]@{rank=$rankList[$_]; url=$urlList[$_];} }
		
		$allList += $list
	}
	
	$myRank = $allList | ?{ $_.url -eq $myUrl } | %{ $_.rank }
	$rankFm = $myRank - $getRankRange
	$rankTo = $myRank + $getRankRange
	return $allList | ? { ($_.rank -ne $myRank) -and ($rankFm -le $_.rank) -and ($_.rank -le $rankTo) } | %{ $_.url }
}


### id,�Ȗ��{��Փx,pp �̃��X�g���擾����֐�

function Get-PpList($url) {

	$w = Invoke-WebRequest $url

	$el = $w.ParsedHtml.querySelectorAll("table.ranking tr IMG")
	$idList = 0..($el.length-1) | % {
	  $el[$_].src  -match "([^/]+).png" > $null
	  $matches[1]
	}

	$el = $w.ParsedHtml.querySelectorAll("table.ranking tr span.pp")
	$nameList = 0..($el.length-1) | % {
	  $el[$_].innerText
	}

	$el = $w.ParsedHtml.querySelectorAll("table.ranking tr span.ppValue")
	$ppList = 0..($el.length-1) | % {
	  $el[$_].innerText
	}

	$list = 0..($idList.Count-1) | %{ [PSCustomObject]@{id=$idList[$_]; name=$nameList[$_]; pp=[int]$ppList[$_]; ppDiff=[int]$ppList[$_]} }

	return $list
}

### ���s

Run-Main

