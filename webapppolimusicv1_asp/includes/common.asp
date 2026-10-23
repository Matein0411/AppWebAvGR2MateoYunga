<!--#include file="config.asp"-->
<%
Response.Buffer = True
Response.CodePage = 65001
Response.Charset = "utf-8"
Response.CacheControl = "no-cache"
Response.AddHeader "Cache-Control", "no-store, private"
Response.AddHeader "X-Content-Type-Options", "nosniff"
Response.AddHeader "X-Frame-Options", "DENY"
Response.AddHeader "Referrer-Policy", "same-origin"
Response.AddHeader "Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; media-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'"
Session.Timeout = 30

Function H(value)
    If IsNull(value) Or IsEmpty(value) Then
        H = ""
    Else
        H = Server.HTMLEncode(CStr(value))
    End If
End Function

Function TextValue(value)
    If IsNull(value) Or IsEmpty(value) Then
        TextValue = ""
    Else
        TextValue = CStr(value)
    End If
End Function

Function IsAdmin()
    IsAdmin = (TextValue(Session("rol")) = "admin")
End Function

Sub RequireLogin()
    If Len(TextValue(Session("usuario"))) = 0 Then
        Response.Redirect "login.asp"
        Response.End
    End If
    If Session("rol") <> "normal" And Session("rol") <> "admin" Then
        Session.Abandon
        Response.Redirect "login.asp"
        Response.End
    End If
End Sub

Sub RequireAdmin()
    RequireLogin
    If Not IsAdmin() Then FailRequest "403 Forbidden", "Solo los administradores pueden gestionar el catálogo."
End Sub

Sub FailRequest(status, message)
    Response.Status = status
    Response.Write "<!doctype html><html lang=""es""><meta charset=""utf-8""><meta name=""viewport"" content=""width=device-width,initial-scale=1""><title>PoliMusic</title><link rel=""stylesheet"" href=""style.css?v=" & H(ASSET_VERSION) & """><main class=""message-page""><a class=""brand"" href=""index.asp"">PoliMusic</a><h1>No se pudo completar la solicitud</h1><p>" & H(message) & "</p><a class=""button primary"" href=""index.asp"">Volver al catálogo</a></main></html>"
    Response.End
End Sub

Function CsrfToken()
    Dim token, i
    If Len(TextValue(Session("csrf"))) = 0 Then
        ' Token inicial ligado a la sesión; al autenticar se reemplaza por NEWID de SQL Server.
        Randomize
        token = CStr(Session.SessionID)
        For i = 1 To 8
            token = token & Hex(Int(Rnd() * 2147483647))
        Next
        Session("csrf") = token
    End If
    CsrfToken = Session("csrf")
End Function

Sub RequirePost()
    If Request.ServerVariables("REQUEST_METHOD") <> "POST" Then
        Response.AddHeader "Allow", "POST"
        FailRequest "405 Method Not Allowed", "Esta operación requiere un formulario POST."
    End If
    If Len(TextValue(Session("csrf"))) = 0 Or TextValue(Request.Form("csrf")) <> TextValue(Session("csrf")) Then
        FailRequest "403 Forbidden", "La sesión del formulario venció. Actualiza la página e inténtalo de nuevo."
    End If
End Sub

Function OpenDatabase()
    Dim connection, failed
    Set connection = Server.CreateObject("ADODB.Connection")
    connection.ConnectionTimeout = 4
    connection.CommandTimeout = 10
    On Error Resume Next
    connection.Open DB_CONNECTION_STRING
    failed = (Err.Number <> 0)
    Err.Clear
    On Error GoTo 0
    If failed Then
        Set OpenDatabase = Nothing
    Else
        Set OpenDatabase = connection
    End If
End Function

Function DbCommand(connection, sql)
    Dim command
    Set command = Server.CreateObject("ADODB.Command")
    Set command.ActiveConnection = connection
    command.CommandType = adCmdText
    command.CommandText = sql
    Set DbCommand = command
End Function

Sub AddParameter(command, name, dataType, size, value)
    command.Parameters.Append command.CreateParameter(name, dataType, adParamInput, size, value)
End Sub

Function PositiveId(value)
    Dim expression, numericValue
    PositiveId = 0
    Set expression = New RegExp
    expression.Pattern = "^[1-9][0-9]{0,9}$"
    If Not expression.Test(TextValue(value)) Then Exit Function
    numericValue = CDbl(value)
    If numericValue <= 2147483647 Then PositiveId = CLng(numericValue)
End Function

Function SafeLocalPath(value)
    Dim path, lowerPath, expression, i, separator, folder, filePart
    path = Replace(Trim(TextValue(value)), "\", "/")
    If Left(path, 2) = "~/" Then path = Mid(path, 3)
    lowerPath = LCase(path)
    SafeLocalPath = ""
    If InStr(path, "..") > 0 Or InStr(path, ":") > 0 Or InStr(path, "%") > 0 Or InStr(path, "?") > 0 Or InStr(path, "#") > 0 Or InStr(path, Chr(0)) > 0 Then Exit Function
    If InStr(path, "//") > 0 Then Exit Function
    Set expression = New RegExp
    expression.Pattern = "[<>""|*]"
    If expression.Test(path) Then Exit Function
    For i = 1 To Len(path)
        If AscW(Mid(path, i, 1)) >= 0 And AscW(Mid(path, i, 1)) < 32 Then Exit Function
    Next
    If Left(lowerPath, 7) <> "assets/" Then
        separator = InStr(path, "/")
        If separator = 0 Then Exit Function
        folder = LCase(Left(path, separator - 1))
        filePart = Mid(path, separator + 1)
        Select Case folder
            Case "songfiles": path = "assets/SongFiles/" & filePart
            Case "albumimages": path = "assets/AlbumImages/" & filePart
            Case "playlistimages": path = "assets/PlaylistImages/" & filePart
            Case "userimages": path = "assets/UserImages/" & filePart
            Case "artistimages": path = "assets/ArtistImages/" & filePart
            Case Else: Exit Function
        End Select
    End If
    SafeLocalPath = path
End Function

Function LocalFileExists(path)
    Dim fs
    LocalFileExists = False
    If Len(path) = 0 Then Exit Function
    Set fs = Server.CreateObject("Scripting.FileSystemObject")
    LocalFileExists = fs.FileExists(Server.MapPath(path))
    Set fs = Nothing
End Function

Function ResourceUrl(value)
    Dim path
    ResourceUrl = ""
    path = SafeLocalPath(value)
    If Len(path) = 0 Then Exit Function
    If LocalFileExists(path) Then ResourceUrl = path
End Function

Function CoverUrl(value, id)
    Dim path
    path = ResourceUrl(value)
    If Len(path) = 0 And Not IsNull(id) Then
        If CLng(id) > 0 Then path = ResourceUrl("assets/PlaylistImages/playlist" & ((CLng(id) - 1) Mod 5 + 1) & ".png")
    End If
    If Len(path) = 0 Then path = "assets/PlaylistImages/default.jpg"
    CoverUrl = path
End Function

Function IsCoverPath(value)
    Dim path, extension, separator
    path = SafeLocalPath(value)
    IsCoverPath = False
    If Len(path) = 0 Then Exit Function
    separator = InStrRev(path, ".")
    If separator = 0 Then Exit Function
    extension = LCase(Mid(path, separator + 1))
    Select Case extension
        Case "jpg", "jpeg", "png", "webp", "gif", "svg": IsCoverPath = True
    End Select
End Function

Function SongCoverUrl(id)
    Dim path
    path = ResourceUrl("assets/SongCovers/cover-" & ((CLng(id) - 1) Mod 5 + 1) & ".svg")
    If Len(path) = 0 Then path = "assets/PlaylistImages/default.jpg"
    SongCoverUrl = path
End Function

Function UserPhotoUrl()
    Dim path
    path = ResourceUrl(Session("foto_usuario"))
    If Len(path) = 0 Then path = "assets/UserImages/default.jpg"
    UserPhotoUrl = path
End Function

Function Icon(name)
    Dim shape
    Select Case name
        Case "play": shape = "<path d='m9 5 11 7-11 7z'/>"
        Case "pause": shape = "<path d='M8 5v14M16 5v14'/>"
        Case "next": shape = "<path d='m5 5 10 7-10 7zM19 5v14'/>"
        Case "previous": shape = "<path d='m19 5-10 7 10 7zM5 5v14'/>"
        Case "search": shape = "<circle cx='10.5' cy='10.5' r='6.5'/><path d='m16 16 4 4'/>"
        Case "home": shape = "<path d='m3 10 9-7 9 7v10H3zM9 20v-7h6v7'/>"
        Case "music": shape = "<path d='M9 17V5l12-2v12M9 9l12-2'/><ellipse cx='6' cy='18' rx='3' ry='3'/><ellipse cx='18' cy='16' rx='3' ry='3'/>"
        Case "disc": shape = "<circle cx='12' cy='12' r='9'/><circle cx='12' cy='12' r='2'/><path d='M6 12a6 6 0 0 1 6-6'/>"
        Case "logout": shape = "<path d='M10 4H4v16h6m5-13 5 5-5 5M9 12h11'/>"
        Case "plus": shape = "<path d='M12 5v14M5 12h14'/>"
        Case "edit": shape = "<path d='m15 4 5 5-11 11H4v-5zM13 6l5 5'/>"
        Case "trash": shape = "<path d='M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7M14 10v7'/>"
        Case "volume": shape = "<path d='M4 9h4l5-4v14l-5-4H4zM17 8a6 6 0 0 1 0 8M20 5a10 10 0 0 1 0 14'/>"
        Case "shuffle": shape = "<path d='M3 6h3c5 0 7 12 12 12h3m-4-4 4 4-4 4M3 18h3c2 0 3-2 5-5m2-3c2-3 3-4 5-4h3m-4-4 4 4-4 4'/>"
        Case "repeat": shape = "<path d='m17 2 4 4-4 4M3 10V6h18M7 22l-4-4 4-4m14 0v4H3'/>"
        Case "arrow": shape = "<path d='M5 12h14m-5-5 5 5-5 5'/>"
        Case "headphones": shape = "<path d='M4 13v-1a8 8 0 0 1 16 0v1M4 12h4v9H4zm12 0h4v9h-4z'/>"
        Case "close": shape = "<path d='m6 6 12 12M6 18 18 6'/>"
        Case "heart": shape = "<path d='M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8z'/>"
        Case "playlist": shape = "<path d='M4 5h14M4 10h14M4 15h8M17 14v7m-3-3.5 3 3.5 3-3.5'/>"
        Case "expand": shape = "<path d='M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5'/>"
        Case "collapse": shape = "<path d='M3 8h5V3m8 0v5h5M8 21v-5H3m13 5v-5h5'/>"
        Case Else: shape = "<circle cx='12' cy='12' r='9'/>"
    End Select
    Icon = "<svg class='icon' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='1.7' stroke-linecap='round' stroke-linejoin='round' aria-hidden='true'>" & shape & "</svg>"
End Function
%>
