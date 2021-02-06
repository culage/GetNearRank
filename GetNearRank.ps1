##########################################################################################
# BeatSaberで順位が近く人がPPを多く取ったランク曲を取得してプレイリストにする
# PPmax < (自身のPP + 20)の曲は除外
##########################################################################################

### 設定

$MY_URL         = "https://scoresaber.com/u/2524699980873617"
$RANK_GET_PAGES = 1..3
$RANK_BASE_URL  = "https://scoresaber.com/global/{rank}&country=jp"
$GET_RANK_RANGE = 3    # 前後何位の人から取得するか
$PP_FILTER      = 20   # 他人が自身のPPよりこれ以上多くPPを取っている曲を出力

### メイン

function Run-Main() {
	# 自身順位の前後url取得関数
	$urlList = Get-UrlList $MY_URL $RANK_BASE_URL $RANK_GET_PAGES $GET_RANK_RANGE

	# 最大ppリスト取得
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

	# PP差を追加（ppDiff初期値はppと同じ。自身に存在するもののみ差に書き換え）
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

	# 結果出力
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


### 自身順位の前後url取得関数

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


### id,曲名＋難易度,pp のリストを取得する関数

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

### 実行

Run-Main

