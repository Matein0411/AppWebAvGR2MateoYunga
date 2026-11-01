param([string]$BaseUrl = 'http://localhost:61247')

# Integration checks against the existing local database. Only random test records
# are changed; finally removes them even if a check fails. Requires PowerShell 7.
$ErrorActionPreference = 'Stop'
[xml]$configuration = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../Web.config')
$connectionSection = $configuration.configuration.connectionStrings
if ($connectionSection.configSource) {
    [xml]$connectionFile = Get-Content -LiteralPath (Join-Path $PSScriptRoot ('../' + $connectionSection.configSource))
    $connectionSection = $connectionFile.connectionStrings
}
$connection = New-Object System.Data.SqlClient.SqlConnection($connectionSection.add.connectionString)
$connection.Open()
$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 12)
$testName = '__PoliMusic_test_' + $suffix
$password = [Guid]::NewGuid().ToString('N')
$sha = [Security.Cryptography.SHA1]::Create()
$hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($password)))).Replace('-', '')
$sha.Dispose()
$userIDs = New-Object 'System.Collections.Generic.List[int]'
$checks = 0

function Sql([string]$Text, [hashtable]$Values = @{}) {
    $command = $connection.CreateCommand()
    try {
        $command.CommandText = $Text
        foreach ($entry in $Values.GetEnumerator()) { [void]$command.Parameters.AddWithValue('@' + $entry.Key, $entry.Value) }
        return $command.ExecuteScalar()
    } finally { $command.Dispose() }
}
function Check([bool]$Condition, [string]$Description) {
    if (-not $Condition) { throw ('FAIL: ' + $Description) }
    $script:checks++
    Write-Output ('PASS: ' + $Description)
}
function GetFields([string]$Html) {
    $fields = @{}
    foreach ($inputTag in [regex]::Matches($Html, '<input\b[^>]*>')) {
        if ($inputTag.Value -notmatch 'type="hidden"') { continue }
        $name = [regex]::Match($inputTag.Value, 'name="([^"]+)"').Groups[1].Value
        $value = [regex]::Match($inputTag.Value, 'value="([^"]*)"').Groups[1].Value
        if ($name) { $fields[$name] = [System.Web.HttpUtility]::HtmlDecode($value) }
    }
    return $fields
}
function Post($Session, [string]$Page, [string]$Html, [hashtable]$Values) {
    $fields = GetFields $Html
    foreach ($entry in $Values.GetEnumerator()) { $fields[$entry.Key] = $entry.Value }
    return Invoke-WebRequest -Uri ($BaseUrl + '/' + $Page) -Method Post -WebSession $Session -Body $fields -UseBasicParsing -SkipHttpErrorCheck
}
function PostFile($Session, [string]$Html, [string]$Filename) {
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.CookieContainer = $Session.Cookies
    $client = [System.Net.Http.HttpClient]::new($handler)
    $multipart = [System.Net.Http.MultipartFormDataContent]::new()
    # Match the quoted field names and unquoted boundary sent by web browsers.
    foreach ($parameter in $multipart.Headers.ContentType.Parameters) {
        if ($parameter.Name -eq 'boundary') { $parameter.Value = $parameter.Value.Trim('"') }
    }
    try {
        $fields = GetFields $Html
        $fields['txtSongName'] = $testName
        $fields['ddlAudioFiles'] = ''
        $fields['btnSave'] = 'Save'
        foreach ($entry in $fields.GetEnumerator()) {
            $part = [System.Net.Http.StringContent]::new([string]$entry.Value)
            $multipart.Add($part, $entry.Key)
            $part.Headers.ContentDisposition.Name = '"' + $entry.Key + '"'
        }
        $bytes = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot '../SongFiles/bensound-adventure.mp3'))
        $fileBody = [System.Net.Http.ByteArrayContent]::new($bytes)
        $fileBody.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::new('audio/mpeg')
        $multipart.Add($fileBody, 'fupSong', $Filename)
        $fileBody.Headers.ContentDisposition.Name = '"fupSong"'
        $fileBody.Headers.ContentDisposition.FileName = '"' + $Filename + '"'
        $fileBody.Headers.ContentDisposition.FileNameStar = $null
        $response = $client.PostAsync(($BaseUrl + '/Song.aspx'), $multipart).GetAwaiter().GetResult()
        try {
            return [pscustomobject]@{ StatusCode=[int]$response.StatusCode; Content=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult() }
        } finally { $response.Dispose() }
    } finally { $multipart.Dispose(); $client.Dispose() }
}
function Login([string]$Username) {
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $page = Invoke-WebRequest -Uri ($BaseUrl + '/Login.aspx') -WebSession $session -UseBasicParsing
    $result = Post $session 'Login.aspx' $page.Content @{ txtLogin=$Username; txtPassword=$password; btnLogin='Login' }
    Check ($result.StatusCode -eq 200 -and $result.Content.Contains('id="songList"')) 'Login redirects to Song.aspx'
    return @{ Session=$session; Page=$result }
}
function EventTarget([string]$Html, [int]$ID, [string]$Button) {
    $Html = [System.Web.HttpUtility]::HtmlDecode($Html)
    $row = [regex]::Match($Html, '(?s)<article class="song-row[^>]*data-id=[\x22\x27]' + $ID + '[\x22\x27].*?</article>').Value
    return [regex]::Match($row, "__doPostBack\('([^']*" + $Button + ")'").Groups[1].Value
}

try {
    $parentCounts = Sql 'SELECT (SELECT COUNT(*) FROM TBL_ALBUM) * 1000000 + (SELECT COUNT(*) FROM TBL_ARTIST) * 1000 + (SELECT COUNT(*) FROM TBL_PLAYLIST)'
    foreach ($role in @(0, 1)) {
        $userID = Sql 'INSERT INTO TBL_USER (USERNAME, PASSWORD, EMAIL, USER_TYPE) VALUES (@name, @hash, @email, @role); SELECT CAST(SCOPE_IDENTITY() AS int)' @{ name=($testName + $role); hash=$hash; email=($suffix + $role + '@example.invalid'); role=$role }
        $userIDs.Add([int]$userID)
    }
    $normalLogin = @(Login ($testName + '0'))
    $normal = $normalLogin[-1]
    $normalLogin[0..($normalLogin.Count-2)] | Write-Output
    $adminLogin = @(Login ($testName + '1'))
    $admin = $adminLogin[-1]
    $adminLogin[0..($adminLogin.Count-2)] | Write-Output
    Check (-not $normal.Page.Content.Contains('id="btnNewSong"')) 'Normal users have no catalog management controls'
    Check ($admin.Page.Content.Contains('id="btnNewSong"')) 'Administrators have catalog management controls'
    $forbidden = Post $normal.Session 'Song.aspx' $normal.Page.Content @{ __EVENTTARGET='btnNewSong'; __EVENTARGUMENT='' }
    Check ($forbidden.StatusCode -eq 403) 'Forged management request from normal user is rejected'
    $csrf = Post $admin.Session 'Song.aspx' $admin.Page.Content @{ csrf='invalid'; __EVENTTARGET='btnNewSong' }
    Check ($csrf.StatusCode -eq 403) 'Invalid CSRF token is rejected'

    $editor = Post $admin.Session 'Song.aspx' $admin.Page.Content @{ __EVENTTARGET='btnNewSong'; __EVENTARGUMENT='' }
    Check ($editor.StatusCode -eq 200 -and $editor.Content.Contains('id="txtSongName"')) 'New song editor opens'
    $invalid = Post $admin.Session 'Song.aspx' $editor.Content @{ txtSongName=' '; ddlAudioFiles='~/SongFiles/bensound-adventure.mp3'; btnSave='Save' }
    Check ($invalid.StatusCode -eq 200 -and $invalid.Content.Contains('entre 1 y 50')) 'Empty song title is rejected'
    $created = Post $admin.Session 'Song.aspx' $invalid.Content @{ txtSongName=$testName; ddlAudioFiles='~/SongFiles/bensound-adventure.mp3'; btnSave='Save' }
    $songID = Sql 'SELECT ID_SONG FROM TBL_SONG WHERE SONG_NAME = @name' @{ name=$testName }
    Check ($created.StatusCode -eq 200 -and $null -ne $songID) 'Song creation persists in SQL Server'
    Check ((Sql 'SELECT PLAYS FROM TBL_SONG WHERE ID_SONG=@id' @{id=$songID}) -eq 0) 'New songs start with zero plays'
    [void](Sql 'INSERT INTO TBL_PLAYER SELECT @id, MIN(ID_ARTIST) FROM TBL_ARTIST HAVING COUNT(*) > 0; INSERT INTO TBL_TRACKLIST SELECT MIN(ID_ALBUM), @id FROM TBL_ALBUM HAVING COUNT(*) > 0; INSERT INTO TBL_PLAYLIST_SONG SELECT MIN(ID_PLAYLIST), @id FROM TBL_PLAYLIST HAVING COUNT(*) > 0' @{id=$songID})
    $linksBefore = Sql 'SELECT (SELECT COUNT(*) FROM TBL_PLAYER WHERE ID_SONG=@id) + (SELECT COUNT(*) FROM TBL_TRACKLIST WHERE ID_SONG=@id) + (SELECT COUNT(*) FROM TBL_PLAYLIST_SONG WHERE ID_SONG=@id)' @{id=$songID}
    $play = Post $admin.Session 'Song.aspx' $created.Content @{ action='play'; id=$songID }
    Check ($play.StatusCode -eq 200 -and $play.Content.Contains('"saved":true')) 'Authenticated playback increments the counter'
    $playAgain = Post $admin.Session 'Song.aspx' $created.Content @{ action='play'; id=$songID }
    Check ($playAgain.Content.Contains('"saved":false')) 'Repeated playback requests are rate limited'
    $editTarget = EventTarget $created.Content $songID 'btnEdit'
    Check ($editTarget.Length -gt 0) 'Created song exposes an edit action'
    $edit = Post $admin.Session 'Song.aspx' $created.Content @{ __EVENTTARGET=$editTarget; __EVENTARGUMENT='' }
    Check ($edit.Content.Contains('value="' + $testName + '"')) 'Edit editor loads the stored title'
    $editedName = "QA O'Brien & Remix " + $suffix
    $updated = Post $admin.Session 'Song.aspx' $edit.Content @{ txtSongName=$editedName; ddlAudioFiles='~/SongFiles/bensound-adventure.mp3'; btnSave='Save' }
    Check ((Sql 'SELECT SONG_NAME FROM TBL_SONG WHERE ID_SONG=@id' @{id=$songID}) -eq $editedName) 'Parameterized update accepts apostrophes and ampersands'
    Check ($updated.Content.Contains('QA O&#39;Brien &amp; Remix')) 'Song titles are HTML encoded'
    Check ((Sql 'SELECT PLAYS FROM TBL_SONG WHERE ID_SONG=@id' @{id=$songID}) -eq 1) 'Editing preserves the playback count'
    $linksAfter = Sql 'SELECT (SELECT COUNT(*) FROM TBL_PLAYER WHERE ID_SONG=@id) + (SELECT COUNT(*) FROM TBL_TRACKLIST WHERE ID_SONG=@id) + (SELECT COUNT(*) FROM TBL_PLAYLIST_SONG WHERE ID_SONG=@id)' @{id=$songID}
    Check ($linksAfter -eq $linksBefore) 'Editing preserves album, artist and playlist relationships'
    $deleteTarget = EventTarget $updated.Content $songID 'btnDelete'
    $deleted = Post $admin.Session 'Song.aspx' $updated.Content @{ __EVENTTARGET=$deleteTarget; __EVENTARGUMENT='' }
    Check ($deleted.StatusCode -eq 200 -and (Sql 'SELECT COUNT(*) FROM TBL_SONG WHERE ID_SONG=@id' @{id=$songID}) -eq 0) 'Deleting a song removes the SQL record'
    $remainingLinks = Sql 'SELECT (SELECT COUNT(*) FROM TBL_PLAYER WHERE ID_SONG=@id) + (SELECT COUNT(*) FROM TBL_TRACKLIST WHERE ID_SONG=@id) + (SELECT COUNT(*) FROM TBL_PLAYLIST_SONG WHERE ID_SONG=@id)' @{id=$songID}
    Check ($remainingLinks -eq 0) 'Deleting a song removes its foreign-key relationships'
    Check ((Sql 'SELECT (SELECT COUNT(*) FROM TBL_ALBUM) * 1000000 + (SELECT COUNT(*) FROM TBL_ARTIST) * 1000 + (SELECT COUNT(*) FROM TBL_PLAYLIST)') -eq $parentCounts) 'Deleting a song preserves albums, artists and playlists'
    Check (Test-Path -LiteralPath (Join-Path $PSScriptRoot '../SongFiles/bensound-adventure.mp3')) 'Deleting a song preserves the shared MP3 file'
    $uploadEditor = Post $admin.Session 'Song.aspx' $deleted.Content @{ __EVENTTARGET='btnNewSong'; __EVENTARGUMENT='' }
    $badUpload = PostFile $admin.Session $uploadEditor.Content 'invalid.txt'
    Check ($badUpload.StatusCode -eq 200 -and $badUpload.Content.Contains('audio MP3') -and (Sql 'SELECT COUNT(*) FROM TBL_SONG WHERE SONG_NAME=@name' @{name=$testName}) -eq 0) 'Non-MP3 uploads are rejected without inserting a song'
    $uploaded = PostFile $admin.Session $badUpload.Content 'test-audio.mp3'
    $songID = Sql 'SELECT ID_SONG FROM TBL_SONG WHERE SONG_NAME=@name' @{name=$testName}
    Check ($uploaded.StatusCode -eq 200 -and $null -ne $songID) 'Multipart MP3 upload creates a song'
    $audioPath = Sql 'SELECT SONG_PATH FROM TBL_SONG WHERE ID_SONG=@id' @{id=$songID}
    Check ($audioPath -match '^~/SongFiles/[a-f0-9]{32}\.mp3$') 'Uploads receive a unique server-generated filename'
    $uploadedPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ('../' + $audioPath.Substring(2))))
    Check (Test-Path -LiteralPath $uploadedPath) 'Uploaded audio is stored inside SongFiles'
    $deleteTarget = EventTarget $uploaded.Content $songID 'btnDelete'
    $removedUpload = Post $admin.Session 'Song.aspx' $uploaded.Content @{ __EVENTTARGET=$deleteTarget; __EVENTARGUMENT='' }
    Check ($removedUpload.StatusCode -eq 200 -and (Sql 'SELECT COUNT(*) FROM TBL_SONG WHERE ID_SONG=@id' @{id=$songID}) -eq 0 -and (Test-Path -LiteralPath $uploadedPath)) 'Deleting an uploaded song preserves its audio file'
    [void](Invoke-WebRequest -Uri ($BaseUrl + '/Logout.aspx') -WebSession $normal.Session -UseBasicParsing)
    $signedOut = Invoke-WebRequest -Uri ($BaseUrl + '/Song.aspx') -WebSession $normal.Session -UseBasicParsing
    Check ($signedOut.Content.Contains('id="txtLogin"') -and -not $signedOut.Content.Contains('id="songList"')) 'Logout invalidates access to the catalog'
    Write-Output ("Completed: $checks integration checks.")
} finally {
    if ($null -ne $songID) {
        [void](Sql 'DELETE FROM TBL_PLAYER WHERE ID_SONG=@id; DELETE FROM TBL_TRACKLIST WHERE ID_SONG=@id; DELETE FROM TBL_PLAYLIST_SONG WHERE ID_SONG=@id; DELETE FROM TBL_SONG WHERE ID_SONG=@id' @{id=$songID})
    }
    foreach ($userID in $userIDs) { [void](Sql 'DELETE FROM TBL_USER WHERE ID_USER=@id' @{id=$userID}) }
    if ($uploadedPath -and (Test-Path -LiteralPath $uploadedPath)) {
        $songDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../SongFiles'))
        if ((Split-Path -Parent $uploadedPath) -eq $songDirectory -and (Split-Path -Leaf $uploadedPath) -match '^[a-f0-9]{32}\.mp3$') {
            Remove-Item -LiteralPath $uploadedPath
        }
    }
    $connection.Dispose()
}
