<%@ Language="VBScript" CodePage="65001" %>
<% Option Explicit %>
<!--#include file="includes/common.asp"-->
<%
RequireLogin
Dim connection, command, records, songRows, albumRows, playlistRows, songCount, albumCount, playlistCount, likesCount, dbError, sql, i
Dim songId, songName, songAudio, songCover, songArtist, firstPlayable, totalPlays, flash
Dim featuredIndex, featuredCover, featuredName, featuredArtist, homeCount
songCount = 0
albumCount = 0
playlistCount = 0
likesCount = 0
totalPlays = 0
firstPlayable = -1
dbError = False
flash = TextValue(Session("flash"))
Session.Contents.Remove "flash"
Set connection = OpenDatabase()
If connection Is Nothing Then
    dbError = True
Else
    sql = "SELECT s.ID_SONG, s.SONG_NAME, s.SONG_PATH, ISNULL(s.PLAYS, 0) AS PLAYS, ISNULL(a.TITLE_ALBUM, 'Sencillo') AS ALBUM_TITLE, a.ALBUM_IMAGE_PATH, " & _
        "ISNULL(STUFF((SELECT ', ' + ar.ARTIST_NAME + CASE WHEN ISNULL(ar.ARTIST_LASTNAME, '') = '' THEN '' ELSE ' ' + ar.ARTIST_LASTNAME END FROM dbo.TBL_PLAYER p INNER JOIN dbo.TBL_ARTIST ar ON ar.ID_ARTIST = p.ID_ARTIST WHERE p.ID_SONG = s.ID_SONG ORDER BY ar.ID_ARTIST FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, ''), 'Artista independiente') AS ARTISTS, " & _
        "ISNULL(STUFF((SELECT ',' + CONVERT(varchar(11), t.ID_ALBUM) FROM dbo.TBL_TRACKLIST t WHERE t.ID_SONG = s.ID_SONG ORDER BY t.ID_ALBUM FOR XML PATH('')), 1, 1, ''), '') AS ALBUM_IDS, a.ID_ALBUM, " & _
        "CASE WHEN EXISTS (SELECT 1 FROM dbo.TBL_PLAYLIST_SONG ls WHERE ls.ID_SONG = s.ID_SONG AND ls.ID_PLAYLIST = (SELECT TOP (1) lp.ID_PLAYLIST FROM dbo.TBL_PLAYLIST lp WHERE lp.ID_USER = ? AND lp.TYPE = 1 AND lp.TITLE = ? ORDER BY lp.ID_PLAYLIST)) THEN 1 ELSE 0 END AS IS_LIKED " & _
        "FROM dbo.TBL_SONG s OUTER APPLY (SELECT TOP (1) al.ID_ALBUM, al.TITLE_ALBUM, al.ALBUM_IMAGE_PATH FROM dbo.TBL_TRACKLIST tl INNER JOIN dbo.TBL_ALBUM al ON al.ID_ALBUM = tl.ID_ALBUM WHERE tl.ID_SONG = s.ID_SONG ORDER BY al.ID_ALBUM) a ORDER BY s.ID_SONG"
    Set command = DbCommand(connection, sql)
    AddParameter command, "userId", adInteger, 4, PositiveId(Session("id_usuario"))
    AddParameter command, "likesTitle", adVarChar, 50, LIKES_PLAYLIST_TITLE
    On Error Resume Next
    Set records = command.Execute
    dbError = (Err.Number <> 0)
    Err.Clear
    On Error GoTo 0
    If Not dbError Then
        If Not records.EOF Then
            songRows = records.GetRows()
            songCount = UBound(songRows, 2) + 1
        End If
        records.Close
        Set records = Nothing
        On Error Resume Next
        Set records = connection.Execute("SELECT a.ID_ALBUM, a.TITLE_ALBUM, a.ALBUM_IMAGE_PATH, COUNT(t.ID_SONG) AS SONG_COUNT, a.RELEASE_YEAR FROM dbo.TBL_ALBUM a LEFT JOIN dbo.TBL_TRACKLIST t ON t.ID_ALBUM = a.ID_ALBUM GROUP BY a.ID_ALBUM, a.TITLE_ALBUM, a.ALBUM_IMAGE_PATH, a.RELEASE_YEAR ORDER BY a.ID_ALBUM")
        dbError = (Err.Number <> 0)
        Err.Clear
        On Error GoTo 0
        If Not dbError Then
            If Not records.EOF Then
                albumRows = records.GetRows()
                albumCount = UBound(albumRows, 2) + 1
            End If
            records.Close
        End If
    End If
    If Not dbError Then
        sql = "SELECT p.ID_PLAYLIST, p.TITLE, p.PHOTO, (SELECT COUNT(*) FROM dbo.TBL_PLAYLIST_SONG ps WHERE ps.ID_PLAYLIST = p.ID_PLAYLIST) AS SONG_COUNT, " & _
            "ISNULL(STUFF((SELECT ',' + CONVERT(varchar(11), ps.ID_SONG) FROM dbo.TBL_PLAYLIST_SONG ps WHERE ps.ID_PLAYLIST = p.ID_PLAYLIST ORDER BY ps.ID_SONG FOR XML PATH('')), 1, 1, ''), '') AS SONG_IDS, p.TYPE " & _
            "FROM dbo.TBL_PLAYLIST p WHERE p.ID_USER = ? AND NOT (p.TYPE = 1 AND p.TITLE = ?) ORDER BY p.CREATION_DATE DESC, p.ID_PLAYLIST DESC"
        Set command = DbCommand(connection, sql)
        AddParameter command, "userId", adInteger, 4, PositiveId(Session("id_usuario"))
        AddParameter command, "likesTitle", adVarChar, 50, LIKES_PLAYLIST_TITLE
        On Error Resume Next
        Set records = command.Execute
        dbError = (Err.Number <> 0)
        Err.Clear
        On Error GoTo 0
        If Not dbError Then
            If Not records.EOF Then
                playlistRows = records.GetRows()
                playlistCount = UBound(playlistRows, 2) + 1
            End If
            records.Close
        End If
    End If
    Set records = Nothing
    Set command = Nothing
    connection.Close
    Set connection = Nothing
End If
If dbError Then Response.Status = "503 Service Unavailable"
For i = 0 To songCount - 1
    totalPlays = totalPlays + CDbl(songRows(3, i))
    If CLng(songRows(9, i)) = 1 Then likesCount = likesCount + 1
    If firstPlayable = -1 Then
        If Len(ResourceUrl(songRows(2, i))) > 0 Then firstPlayable = i
    End If
Next
featuredIndex = firstPlayable
If featuredIndex < 0 And songCount > 0 Then featuredIndex = 0
featuredCover = "assets/PlaylistImages/default.jpg"
featuredName = "Tu próximo descubrimiento"
featuredArtist = "Elige la música que va contigo."
If featuredIndex >= 0 Then
    featuredCover = SongCoverUrl(songRows(0, featuredIndex))
    featuredName = TextValue(songRows(1, featuredIndex))
    featuredArtist = TextValue(songRows(6, featuredIndex))
End If

Sub CollectionCard(kind, id, title, photo, count, songIds)
    Dim label, countLabel
    label = "Álbum"
    If kind = "playlist" Then label = "Playlist"
    countLabel = " canciones"
    If CLng(count) = 1 Then countLabel = " canción"
    Response.Write "<button class=""album-card collection-card"" type=""button"" data-" & kind & "-id=""" & CLng(id) & """ data-title=""" & H(title) & """ data-song-ids=""" & H(songIds) & """ aria-label=""Abrir " & H(title) & """><span class=""album-art""><img src=""" & H(CoverUrl(photo, id)) & """ alt=""Portada de " & H(title) & """ loading=""lazy""><span class=""album-open"">" & Icon("arrow") & "</span></span><strong>" & H(title) & "</strong><small>" & CLng(count) & countLabel & " · " & label & "</small></button>"
End Sub

Function LikeButton(index)
    Dim pressed, label, preposition
    pressed = "false"
    label = "Guardar "
    preposition = " en "
    If CLng(songRows(9, index)) = 1 Then
        pressed = "true"
        label = "Quitar "
        preposition = " de "
    End If
    LikeButton = "<button class=""icon-button like-button"" type=""button"" data-like-index=""" & index & """ aria-pressed=""" & pressed & """ aria-label=""" & label & H(songRows(1, index)) & preposition & "Mis me gusta"">" & Icon("heart") & "</button>"
End Function
%>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#ffffff">
    <title>Tu música · PoliMusic</title>
    <link rel="icon" href="assets/PlaylistImages/default.jpg" type="image/jpeg">
    <link rel="stylesheet" href="style.css?v=<%= H(ASSET_VERSION) %>">
    <script src="app.js?v=<%= H(ASSET_VERSION) %>" defer></script>
</head>
<body class="app-page" data-username="<%= H(Session("usuario")) %>" data-admin="<% If IsAdmin() Then %>true<% Else %>false<% End If %>" data-catalog-error="<% If dbError Then %>true<% Else %>false<% End If %>">
    <a class="skip-link" href="#main">Saltar al contenido</a>
    <aside class="sidebar">
        <a class="brand" href="#inicio" aria-label="PoliMusic, Inicio"><span class="brand-mark"><%= Icon("music") %></span>PoliMusic<span class="brand-dot">.</span></a>
        <div class="nav-label">DESCUBRE</div>
        <nav aria-label="Navegación principal">
            <a class="nav-item active" href="#inicio" data-nav="home" aria-current="page" aria-label="Inicio" title="Inicio"><%= Icon("home") %><span class="nav-text">Inicio</span><span class="nav-dot"></span></a>
            <a class="nav-item" href="#me-gusta" data-nav="likes" aria-label="Mis me gusta" title="Mis me gusta"><%= Icon("heart") %><span class="nav-text">Mis me gusta</span><span class="nav-count" data-likes-count><%= likesCount %></span></a>
            <a class="nav-item" href="#playlists" data-nav="playlists" aria-label="Mis playlists" title="Mis playlists"><%= Icon("playlist") %><span class="nav-text">Mis playlists</span></a>
            <a class="nav-item" href="#albumes" data-nav="albums" aria-label="Álbumes" title="Álbumes"><%= Icon("disc") %><span class="nav-text">Álbumes</span></a>
        </nav>
        <div class="sidebar-divider"></div>
        <div class="nav-label">TU ESPACIO</div>
        <div class="library-note"><span class="library-icon"><%= Icon("headphones") %></span><strong>La música va contigo</strong><p>Guarda con el corazón las canciones que quieras volver a escuchar.</p><a href="#me-gusta">Tu colección personal <%= Icon("arrow") %></a></div>
        <% If IsAdmin() Then %><a class="nav-item admin-nav" href="#catalogo" data-nav="admin" aria-label="Gestionar catálogo" title="Gestionar catálogo"><%= Icon("edit") %><span class="nav-text">Gestionar catálogo</span></a><% End If %>
        <div class="sidebar-bottom"><span class="connection-dot"></span> Tu dosis diaria de buena música <span>POLIMUSIC · EST. 2026</span></div>
    </aside>

    <div class="app-content">
        <header class="topbar">
            <div class="breadcrumb">Tu espacio <span>/</span> <strong id="breadcrumb-title">Inicio</strong></div>
            <label class="search-box" for="search"><%= Icon("search") %><input id="search" type="search" placeholder="Busca canciones, artistas o álbumes" autocomplete="off" aria-label="Buscar en el catálogo"><kbd>/</kbd></label>
            <div class="account"><img class="avatar" src="<%= H(UserPhotoUrl()) %>" alt="Foto de <%= H(Session("usuario")) %>"><span class="account-copy"><strong><%= H(Session("usuario")) %></strong><small><% If IsAdmin() Then %>Administrador<% Else %>Cuenta personal<% End If %></small></span><form method="post" action="logout.asp"><input type="hidden" name="csrf" value="<%= H(CsrfToken()) %>"><button class="icon-button logout-button" type="submit" title="Cerrar sesión" aria-label="Cerrar sesión"><%= Icon("logout") %><span class="logout-label">Salir</span></button></form></div>
        </header>

        <main id="main" class="main-content">
            <div class="page-intro"><div><span class="eyebrow" id="page-eyebrow">MÚSICA QUE VA CONTIGO</span><h1 id="page-title">Hola, <%= H(Session("usuario")) %><span class="hello-dot">.</span></h1><p id="page-subtitle">Encuentra el ritmo que va contigo.</p></div><span class="role-pill"><span class="connection-dot"></span><% If IsAdmin() Then %>Modo administrador<% Else %>Tu espacio musical<% End If %></span></div>
            <% If Len(flash) > 0 Then %><div class="notice success" role="status"><%= H(flash) %></div><% End If %>
            <% If dbError Then %><div class="notice error" role="alert">El catálogo no está disponible en este momento. Comprueba la conexión a SQL Server e inténtalo de nuevo. <a href="index.asp">Reintentar</a></div><% End If %>
            <% If IsAdmin() Then %><nav class="admin-tabs" id="admin-tabs" aria-label="Gestión del catálogo" hidden><a href="#catalogo" data-admin-tab="admin"><%= Icon("music") %> Canciones</a><a href="#gestionar-albumes" data-admin-tab="adminAlbums"><%= Icon("disc") %> Álbumes</a></nav><% End If %>

            <section id="inicio" data-view="home">
                <section class="hero discovery-hero" aria-labelledby="hero-title">
                    <div class="hero-copy"><span class="hero-tag"><%= Icon("headphones") %> EN TU FRECUENCIA</span><h2 id="hero-title">Una canción.<br> Otro estado de ánimo.</h2><p><strong><%= H(featuredName) %></strong><br><%= H(featuredArtist) %></p><div class="hero-actions"><button class="button dark" type="button" data-play-index="<%= featuredIndex %>" <% If firstPlayable < 0 Then %>disabled<% End If %>><%= Icon("play") %> Escuchar ahora</button><% If featuredIndex >= 0 Then Response.Write LikeButton(featuredIndex) %></div></div>
                    <button class="featured-cover-button" type="button" data-open-player="<%= featuredIndex %>" aria-label="Abrir el reproductor ampliado" <% If featuredIndex < 0 Then %>disabled<% End If %>><img src="<%= H(featuredCover) %>" alt="Portada de <%= H(featuredName) %>"><span><%= Icon("expand") %></span></button>
                </section>
                <section class="home-songs" aria-labelledby="home-songs-title"><div class="section-heading"><div><span class="eyebrow">DALE PLAY A LO QUE SIENTES</span><h2 id="home-songs-title">Descubre canciones</h2></div><a class="text-button" href="#buscar">Explorar catálogo <%= Icon("arrow") %></a></div><div class="song-card-grid">
                <% homeCount = songCount
                    If homeCount > 5 Then homeCount = 5
                    For i = 0 To homeCount - 1 %>
                    <article class="song-card" data-home-track="<%= i %>"><button class="song-card-art" type="button" data-open-player="<%= i %>" aria-label="Ver <%= H(songRows(1, i)) %> en el reproductor"><img src="<%= H(SongCoverUrl(songRows(0, i))) %>" alt="Portada de <%= H(songRows(1, i)) %>" loading="lazy"><span><%= Icon("expand") %></span></button><div class="song-card-info"><div><strong><%= H(songRows(1, i)) %></strong><small><%= H(songRows(6, i)) %></small></div><%= LikeButton(i) %></div><button class="text-button song-card-play" type="button" data-play-index="<%= i %>" <% If Len(ResourceUrl(songRows(2, i))) = 0 Then %>disabled<% End If %>><%= Icon("play") %><% If Len(ResourceUrl(songRows(2, i))) = 0 Then %>Audio no disponible<% Else %>Reproducir<% End If %></button></article>
                <% Next %>
                </div><% If songCount = 0 And Not dbError Then %><p class="muted">Las canciones del catálogo aparecerán aquí.</p><% End If %></section>
                <section class="home-collections"><div class="section-heading"><div><span class="eyebrow">ENCUENTRA TU AMBIENTE</span><h2><% If playlistCount > 0 Then %>Tus playlists<% Else %>Explora los álbumes<% End If %></h2></div><a class="text-button" href="<% If playlistCount > 0 Then %>#playlists<% Else %>#albumes<% End If %>">Ver todo <%= Icon("arrow") %></a></div><div class="collection-grid">
                <% If playlistCount > 0 Then
                    homeCount = playlistCount
                    If homeCount > 3 Then homeCount = 3
                    For i = 0 To homeCount - 1
                        CollectionCard "playlist", playlistRows(0, i), playlistRows(1, i), playlistRows(2, i), playlistRows(3, i), playlistRows(4, i)
                    Next
                Else
                    homeCount = albumCount
                    If homeCount > 3 Then homeCount = 3
                    For i = 0 To homeCount - 1
                        CollectionCard "album", albumRows(0, i), albumRows(1, i), albumRows(2, i), albumRows(3, i), ""
                    Next
                End If %>
                </div></section>
            </section>

            <section id="albumes" class="album-section" data-view="albums" aria-labelledby="albums-title" hidden>
                <div class="section-heading"><h2 id="albums-title">Una portada, mil sensaciones</h2><% If IsAdmin() Then %><a class="text-button" href="#gestionar-albumes">Gestionar álbumes <%= Icon("edit") %></a><% End If %></div>
                <div class="album-grid">
                <% For i = 0 To albumCount - 1 %>
                    <% CollectionCard "album", albumRows(0, i), albumRows(1, i), albumRows(2, i), albumRows(3, i), "" %>
                <% Next %>
                </div>
                <% If albumCount = 0 And Not dbError Then %><p class="muted">Los álbumes del catálogo aparecerán aquí.</p><% End If %>
            </section>

            <% If IsAdmin() Then %>
            <section class="admin-albums" data-view="adminAlbums" aria-labelledby="admin-albums-title" hidden>
                <div class="section-heading"><h2 id="admin-albums-title">Álbumes del catálogo <span class="count-badge" id="admin-album-count"><%= albumCount %></span></h2><a class="button primary compact" href="album.asp"><%= Icon("plus") %> Agregar álbum</a></div>
                <p class="field-help">Organiza sus canciones y portadas. Al eliminar un álbum, sus canciones permanecen en el catálogo.</p>
                <div class="admin-album-list" role="list" aria-label="Álbumes para administrar">
                <% For i = 0 To albumCount - 1 %>
                    <article class="admin-album-row" role="listitem" data-admin-album data-title="<%= H(albumRows(1, i)) %>" data-year="<%= H(albumRows(4, i)) %>">
                        <a class="admin-album-cover" href="#album/<%= CLng(albumRows(0, i)) %>" aria-label="Ver canciones de <%= H(albumRows(1, i)) %>"><img src="<%= H(CoverUrl(albumRows(2, i), albumRows(0, i))) %>" alt="Portada de <%= H(albumRows(1, i)) %>" loading="lazy"></a>
                        <div class="admin-album-copy"><a href="#album/<%= CLng(albumRows(0, i)) %>"><strong><%= H(albumRows(1, i)) %></strong></a><span><% If Len(TextValue(albumRows(4, i))) > 0 Then %><%= H(albumRows(4, i)) %><% Else %>Sin año<% End If %> · <%= CLng(albumRows(3, i)) %>&nbsp;<% If CLng(albumRows(3, i)) = 1 Then %>canción<% Else %>canciones<% End If %></span></div>
                        <div class="admin-album-actions"><a class="button secondary compact" href="album.asp?id=<%= CLng(albumRows(0, i)) %>" aria-label="Editar álbum <%= H(albumRows(1, i)) %>"><%= Icon("edit") %><span>Editar</span></a><button class="icon-button danger-button" type="button" data-delete-album="<%= CLng(albumRows(0, i)) %>" data-album-name="<%= H(albumRows(1, i)) %>" aria-label="Eliminar álbum <%= H(albumRows(1, i)) %>"><%= Icon("trash") %></button></div>
                    </article>
                <% Next %>
                </div>
                <div class="empty-state" id="admin-albums-empty" hidden><span><%= Icon("disc") %></span><h3>No hay álbumes para mostrar</h3><p>Prueba otra búsqueda o agrega tu primer álbum.</p></div>
            </section>
            <% End If %>

            <section id="playlists" data-view="playlists" hidden><div class="collection-grid"><% For i = 0 To playlistCount - 1
                CollectionCard "playlist", playlistRows(0, i), playlistRows(1, i), playlistRows(2, i), playlistRows(3, i), playlistRows(4, i)
                Next %></div><% If playlistCount = 0 And Not dbError Then %><div class="empty-state"><span><%= Icon("playlist") %></span><h3>Aquí vive tu música organizada</h3><p>Las playlists de tu cuenta aparecerán aquí. Tus canciones guardadas están en Mis me gusta.</p><a href="#me-gusta" class="button primary">Ir a Mis me gusta</a></div><% End If %></section>

            <section id="catalogo" class="catalog-section" data-view="tracks" aria-labelledby="catalog-title" hidden>
                <div class="liked-intro" id="liked-intro" hidden><span class="liked-cover"><%= Icon("heart") %></span><div><span class="eyebrow">TU COLECCIÓN PERSONAL</span><h2>Mis me gusta</h2><p><span data-likes-count><%= likesCount %></span> <span id="likes-description">canciones guardadas por ti.</span></p></div></div>
                <div class="section-heading"><h2 id="catalog-title"><span id="list-title">Canciones</span><span class="count-badge" id="song-count"><%= songCount %></span></h2><div class="list-actions"><button class="button primary compact" id="play-collection" type="button"><%= Icon("play") %> Reproducir</button><% If IsAdmin() Then %><a class="button secondary compact" data-admin-action href="cancion.asp" hidden><%= Icon("plus") %> Agregar canción</a><% End If %></div></div>
                <div class="catalog-filter" id="filter-info" hidden><span id="filter-label"></span><button class="text-button" type="button" id="clear-filter">Quitar filtros <%= Icon("close") %></button></div>
                <div class="track-list" role="list" aria-label="Catálogo de canciones">
                    <div class="track-header" aria-hidden="true"><span>#</span><span>CANCIÓN / ARTISTA</span><span>ÁLBUM</span><span>ESCUCHAS</span><span></span></div>
                    <% For i = 0 To songCount - 1
                        songId = CLng(songRows(0, i))
                        songName = TextValue(songRows(1, i))
                        songAudio = ResourceUrl(songRows(2, i))
                        songCover = SongCoverUrl(songId)
                        songArtist = TextValue(songRows(6, i))
                    %>
                    <article class="track-row" role="listitem" data-track-index="<%= i %>" data-id="<%= songId %>" data-name="<%= H(songName) %>" data-artist="<%= H(songArtist) %>" data-album="<%= H(songRows(4, i)) %>" data-album-ids="<%= H(songRows(7, i)) %>" data-src="<%= H(songAudio) %>" data-cover="<%= H(songCover) %>" data-liked="<% If CLng(songRows(9, i)) = 1 Then %>true<% Else %>false<% End If %>">
                        <button class="track-play icon-button" type="button" data-play-index="<%= i %>" aria-label="Reproducir <%= H(songName) %>" <% If Len(songAudio) = 0 Then %>disabled title="Audio no disponible en los recursos locales"<% End If %>><span class="track-number"><%= i + 1 %></span><span class="track-play-symbol"><%= Icon("play") %></span></button>
                        <div class="track-identity"><img src="<%= H(songCover) %>" alt="" loading="lazy"><div><strong><%= H(songName) %></strong><span><%= H(songArtist) %></span><% If Len(songAudio) = 0 Then %><small class="unavailable">Audio no disponible</small><% End If %></div></div>
                        <span class="track-album"><%= H(songRows(4, i)) %></span><span class="track-plays"><%= H(songRows(3, i)) %></span>
                        <div class="track-actions"><%= LikeButton(i) %><% If IsAdmin() Then %><a class="icon-button" data-admin-action hidden href="cancion.asp?id=<%= songId %>" title="Editar <%= H(songName) %>" aria-label="Editar <%= H(songName) %>"><%= Icon("edit") %></a><button class="icon-button danger-button" data-admin-action hidden type="button" data-delete-id="<%= songId %>" data-delete-name="<%= H(songName) %>" title="Eliminar <%= H(songName) %>" aria-label="Eliminar <%= H(songName) %>"><%= Icon("trash") %></button><% End If %></div>
                    </article>
                    <% Next %>
                </div>
                <div class="empty-state" id="empty-state" hidden><span><%= Icon("heart") %></span><h3 id="empty-title">Tu colección comienza contigo</h3><p id="empty-description">Marca el corazón de una canción para guardarla aquí.</p><a class="button secondary" href="#inicio" id="empty-home">Explorar Inicio</a></div>
            </section>
            <footer class="content-footer"><span>La vida tiene su propio ritmo. Encuentra el tuyo.</span><span>POLIMUSIC <span class="footer-dot">●</span> <%= songCount %> canciones · <%= H(totalPlays) %> escuchas</span></footer>
        </main>
    </div>

    <footer class="music-player" aria-label="Reproductor de música" data-csrf="<%= H(CsrfToken()) %>">
        <audio id="audio" preload="metadata"></audio>
        <button class="now-playing now-playing-button" type="button" data-open-player="current" aria-label="Ampliar reproductor" <% If songCount = 0 Then %>disabled<% End If %>><img id="player-cover" src="assets/PlaylistImages/default.jpg" alt="Portada de la canción actual"><span class="now-playing-copy"><strong id="player-title">Tu siguiente buen momento</strong><span id="player-artist">Elige una canción para empezar</span></span><span class="playing-bars" id="playing-bars" hidden><i></i><i></i><i></i></span></button>
        <div class="player-center"><div class="player-buttons"><button id="shuffle" data-control="shuffle" class="icon-button secondary-control" type="button" aria-label="Reproducción aleatoria" aria-pressed="false"><%= Icon("shuffle") %></button><button id="previous" data-control="previous" class="icon-button" type="button" aria-label="Canción anterior" disabled><%= Icon("previous") %></button><button id="toggle-play" data-control="toggle" class="round-play" type="button" aria-label="Reproducir" disabled><span class="play-glyph"><%= Icon("play") %></span><span class="pause-glyph" hidden><%= Icon("pause") %></span></button><button id="next" data-control="next" class="icon-button" type="button" aria-label="Canción siguiente" disabled><%= Icon("next") %></button><button id="repeat" data-control="repeat" class="icon-button secondary-control" type="button" aria-label="Repetir canción" aria-pressed="false"><%= Icon("repeat") %></button></div><div class="seek-line"><span data-current-time>0:00</span><input id="seek" data-seek type="range" min="0" max="100" step="0.1" value="0" aria-label="Posición de reproducción" disabled><span data-duration>0:00</span></div></div>
        <div class="player-end"><button class="icon-button like-button" data-like-current type="button" aria-label="Guardar canción actual en Mis me gusta" aria-pressed="false" disabled><%= Icon("heart") %></button><span class="player-volume"><%= Icon("volume") %><input id="volume" data-volume type="range" min="0" max="1" step="0.01" value="0.75" aria-label="Volumen"></span><button class="icon-button" type="button" data-open-player="current" aria-label="Abrir reproductor ampliado" <% If songCount = 0 Then %>disabled<% End If %>><%= Icon("expand") %></button></div>
        <p id="player-status" class="player-status" role="status" aria-live="polite"></p>
    </footer>
    <dialog id="expanded-player" class="expanded-player" aria-labelledby="expanded-title">
        <header class="expanded-header"><span><%= Icon("disc") %> AHORA SUENA</span><div><button class="icon-button" id="browser-fullscreen" type="button" aria-label="Activar pantalla completa" aria-pressed="false"><%= Icon("expand") %></button><button class="icon-button" id="close-expanded" type="button" aria-label="Cerrar reproductor ampliado"><%= Icon("collapse") %></button></div></header>
        <div class="expanded-body"><img id="expanded-cover" class="expanded-cover" src="assets/PlaylistImages/default.jpg" alt="Portada de la canción actual"><div class="expanded-info"><span class="eyebrow">EN TU FRECUENCIA</span><div class="expanded-title-row"><h2 id="expanded-title">Tu siguiente buen momento</h2><button class="icon-button like-button" data-like-current type="button" aria-label="Guardar canción actual en Mis me gusta" aria-pressed="false" disabled><%= Icon("heart") %></button></div><p id="expanded-artist">Elige una canción para empezar</p><div class="expanded-progress"><input data-seek type="range" min="0" max="100" step="0.1" value="0" aria-label="Posición en reproductor ampliado" disabled><div><span data-current-time>0:00</span><span data-duration>0:00</span></div></div><div class="expanded-controls"><button data-control="shuffle" class="icon-button secondary-control" type="button" aria-label="Aleatorio en reproductor ampliado" aria-pressed="false"><%= Icon("shuffle") %></button><button data-control="previous" class="icon-button" type="button" aria-label="Anterior en reproductor ampliado" disabled><%= Icon("previous") %></button><button data-control="toggle" class="round-play" type="button" aria-label="Reproducir" disabled><span class="play-glyph"><%= Icon("play") %></span><span class="pause-glyph" hidden><%= Icon("pause") %></span></button><button data-control="next" class="icon-button" type="button" aria-label="Siguiente en reproductor ampliado" disabled><%= Icon("next") %></button><button data-control="repeat" class="icon-button secondary-control" type="button" aria-label="Repetir en reproductor ampliado" aria-pressed="false"><%= Icon("repeat") %></button></div><label class="expanded-volume"><%= Icon("volume") %><input data-volume type="range" min="0" max="1" step="0.01" value="0.75" aria-label="Volumen en reproductor ampliado"></label><p class="expanded-status" id="expanded-status" role="status" aria-live="polite"></p><span class="expanded-signature">LA MÚSICA SE QUEDA. EL RUIDO SE VA.</span></div></div>
    </dialog>
    <% If IsAdmin() Then %>
    <dialog id="delete-album-dialog" class="confirm-dialog" aria-labelledby="delete-album-title"><form method="post" action="procesar-album.asp"><input type="hidden" name="csrf" value="<%= H(CsrfToken()) %>"><input type="hidden" name="action" value="delete"><input type="hidden" id="delete-album-id" name="id"><span class="dialog-icon"><%= Icon("disc") %></span><h2 id="delete-album-title">¿Eliminar este álbum?</h2><p>Se eliminará <strong id="delete-album-name"></strong> y su selección de canciones. Las canciones seguirán disponibles en el catálogo, sus otros álbumes y playlists.</p><div class="form-actions"><button class="button secondary" id="cancel-delete-album" type="button">Cancelar</button><button class="button danger" type="submit">Eliminar álbum</button></div></form></dialog>
    <dialog id="delete-dialog" class="confirm-dialog"><form method="post" action="procesar.asp"><input type="hidden" name="csrf" value="<%= H(CsrfToken()) %>"><input type="hidden" name="action" value="delete"><input type="hidden" id="delete-song-id" name="id"><span class="dialog-icon"><%= Icon("trash") %></span><h2>¿Eliminar esta canción?</h2><p>Se eliminará <strong id="delete-song-name"></strong> del catálogo y de sus álbumes, artistas y listas de reproducción. El archivo de audio se conservará.</p><div class="form-actions"><button class="button secondary" id="cancel-delete" type="button">Cancelar</button><button class="button danger" type="submit">Eliminar canción</button></div></form></dialog>
    <% End If %>
</body>
</html>
