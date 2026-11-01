<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Song.aspx.cs" Inherits="WebAppPoliMusicV2.Song" %>
<!DOCTYPE html>
<html lang="es">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#121212" />
    <title>Tu música · PoliMusic</title>
    <link rel="icon" href="SongCovers/cover-1.svg" type="image/svg+xml" />
    <link rel="stylesheet" href="Content/polimusic.css" />
    <script src="Scripts/song.js" defer></script>
</head>
<body>
    <a class="skip-link" href="#main">Saltar al catálogo</a>
    <form id="formSong" runat="server" enctype="multipart/form-data">
        <input type="hidden" name="csrf" value="<%= H(CsrfToken) %>" />
        <div class="app-shell">
            <aside class="sidebar" aria-label="Navegación principal">
                <a class="brand" href="Song.aspx"><span class="brand-mark"><svg><use href="Content/icons.svg#wave" /></svg></span>PoliMusic<span class="brand-dot">.</span></a>
                <nav class="main-nav">
                    <a href="#main" class="nav-link selected"><svg><use href="Content/icons.svg#home" /></svg>Inicio</a>
                    <button type="button" class="nav-link" id="navSearch"><svg><use href="Content/icons.svg#search" /></svg>Buscar</button>
                </nav>
                <div class="library-title"><svg><use href="Content/icons.svg#library" /></svg><span>Tu biblioteca</span></div>
                <button type="button" class="library-item" data-filter="all"><span class="library-art gradient-green"><svg><use href="Content/icons.svg#music" /></svg></span><span><strong>Todas las canciones</strong><small>Tu colección de sonidos</small></span></button>
                <button type="button" class="library-item" data-filter="available"><img class="library-art" src="SongCovers/cover-1.svg" alt="" /><span><strong>Listas para sonar</strong><small>Escucha los MP3 disponibles</small></span></button>
                <button type="button" class="library-item" data-filter="popular"><img class="library-art" src="SongCovers/cover-3.svg" alt="" /><span><strong>En repetición</strong><small>Las más escuchadas</small></span></button>
                <div class="sidebar-note"><span class="eyebrow">HECHO PARA ESCUCHAR</span><p>Un buen día empieza<br />con una buena canción.</p><span class="small-muted">PoliMusic · Web Player</span></div>
                <a class="logout-link" href="Logout.aspx"><svg><use href="Content/icons.svg#logout" /></svg>Cerrar sesión</a>
            </aside>

            <main id="main" class="main-panel">
                <header class="topbar">
                    <div class="search-box"><svg><use href="Content/icons.svg#search" /></svg><input id="songSearch" type="search" placeholder="¿Qué quieres escuchar?" aria-label="Buscar canción, artista o álbum" autocomplete="off" /><kbd>/</kbd></div>
                    <div class="profile"><span class="profile-copy"><strong><%= H(CurrentUser.UserName) %></strong><small><%= IsAdmin ? "Administrador" : "Tu cuenta" %></small></span><img src="<%= H(UserPhoto()) %>" alt="Tu foto de perfil" /><a class="mobile-logout icon-button" href="Logout.aspx" aria-label="Cerrar sesión"><svg><use href="Content/icons.svg#logout" /></svg></a></div>
                </header>
                <div class="page-content">
                    <div class="welcome-row"><div><span class="eyebrow">TU ESPACIO, TU MÚSICA</span><h1>Hola, <%= H(CurrentUser.UserName) %><span class="green-dot">.</span></h1></div><span class="session-label"><span></span>Qué bueno tenerte aquí</span></div>
                    <asp:Panel ID="pnlMessage" runat="server" Visible="false" role="status"><asp:Label ID="lblMessage" runat="server" /></asp:Panel>
                    <section class="hero" aria-labelledby="heroTitle">
                        <div class="hero-copy"><span class="hero-tag"><span></span>DALE PLAY A TU DÍA</span><h2 id="heroTitle">El mundo en pausa.<br />Tu música, a todo.</h2><p>Redescubre tus favoritas y encuentra tu próximo<br class="desktop-break" /> sonido. Aquí, el ritmo lo pones tú.</p><div class="hero-actions"><button id="heroPlay" type="button" class="button primary"><svg><use href="Content/icons.svg#play" /></svg>Escuchar ahora</button><a href="#canciones" class="hero-link">Explorar catálogo <span aria-hidden="true">↗</span></a></div></div>
                        <div class="hero-art" aria-hidden="true"><div class="record"><div class="record-label"><svg><use href="Content/icons.svg#wave" /></svg></div></div><img src="SongCovers/cover-2.svg" alt="" /><span class="art-caption">SOUNDS LIKE YOU.</span></div>
                    </section>
                    <section class="featured-section" aria-labelledby="featuredTitle">
                        <div class="section-heading"><div><h2 id="featuredTitle">Encuentra tu ritmo</h2><p>Una selección de tu catálogo, siempre a mano.</p></div><a href="#canciones" class="text-link">Ver canciones <span aria-hidden="true">→</span></a></div>
                        <div class="featured-grid">
                            <asp:Repeater ID="rptFeatured" runat="server"><ItemTemplate>
                                <article class="song-card"><div class="card-image"><img src='<%# H(Eval("COVER_URL")) %>' alt='<%# H("Portada de " + Eval("SONG_NAME")) %>' loading="lazy" /><button type="button" class="card-play" data-play-id='<%# Eval("ID_SONG") %>' aria-label='<%# H("Reproducir " + Eval("SONG_NAME")) %>' <%# Disabled(Eval("AUDIO_URL")) %>><svg><use href="Content/icons.svg#play" /></svg></button></div><h3><%# H(Eval("SONG_NAME")) %></h3><p><%# H(Eval("ARTIST")) %></p><span class="card-meta"><%# string.IsNullOrEmpty(Convert.ToString(Eval("AUDIO_URL"))) ? "Audio no disponible" : "LISTA PARA SONAR" %></span></article>
                            </ItemTemplate></asp:Repeater>
                        </div>
                    </section>
                    <section id="canciones" class="catalog-section" aria-labelledby="catalogTitle">
                        <div class="section-heading"><div><span class="eyebrow">TU COLECCIÓN</span><h2 id="catalogTitle">Todas las canciones</h2><p><asp:Label ID="lblSongCount" runat="server" /> <span class="separator">·</span> <asp:Label ID="lblAvailable" runat="server" /></p></div><asp:Panel ID="pnlAdmin" runat="server"><asp:LinkButton ID="btnNewSong" runat="server" CssClass="button secondary" OnClick="NewSong_Click" CausesValidation="false"><svg><use href="Content/icons.svg#plus" /></svg>Añadir canción</asp:LinkButton></asp:Panel></div>
                        <div class="catalog-tools"><div class="filter-chips" aria-label="Filtrar canciones"><button type="button" class="chip active" data-filter="all" aria-pressed="true">Todas</button><button type="button" class="chip" data-filter="available" aria-pressed="false">Con audio</button><button type="button" class="chip" data-filter="popular" aria-pressed="false">Más escuchadas</button></div><span class="catalog-hint"><svg><use href="Content/icons.svg#headphones" /></svg>Tu próxima favorita está aquí</span></div>
                        <div id="catalogHeader" runat="server" class="song-columns list-heading" aria-hidden="true"><span>#</span><span>TÍTULO</span><span class="album-column">ÁLBUM</span><span class="plays-column">REPRODUCCIONES</span><span></span></div>
                        <div id="songList" class="song-list">
                            <asp:Repeater ID="rptSongs" runat="server"><ItemTemplate>
                                <article class="song-row song-columns" data-id='<%# Eval("ID_SONG") %>' data-name='<%# H(Eval("SONG_NAME")) %>' data-artist='<%# H(Eval("ARTIST")) %>' data-album='<%# H(Eval("ALBUM")) %>' data-plays='<%# Eval("PLAYS") %>' data-cover='<%# H(Eval("COVER_URL")) %>' data-audio='<%# H(Eval("AUDIO_URL")) %>'>
                                    <button type="button" class="row-play" data-play-id='<%# Eval("ID_SONG") %>' aria-label='<%# H("Reproducir " + Eval("SONG_NAME")) %>' <%# Disabled(Eval("AUDIO_URL")) %>><span class="row-number"><%# Eval("POSITION") %></span><svg><use href="Content/icons.svg#play" /></svg></button>
                                    <div class="song-title"><img src='<%# H(Eval("COVER_URL")) %>' alt="" loading="lazy" /><div><strong><%# H(Eval("SONG_NAME")) %></strong><span><%# H(Eval("ARTIST")) %><%# string.IsNullOrEmpty(Convert.ToString(Eval("AUDIO_URL"))) ? " · Audio no disponible" : "" %></span></div></div>
                                    <span class="album-column"><%# H(Eval("ALBUM")) %></span><span class="plays-column play-count"><%# Eval("PLAYS", "{0:N0}") %></span>
                                    <div class="row-actions"><asp:LinkButton ID="btnEdit" runat="server" Visible='<%# IsAdmin %>' CommandName="EditSong" CommandArgument='<%# Eval("ID_SONG") %>' OnCommand="Song_Command" CssClass="icon-button" ToolTip="Editar canción" CausesValidation="false"><svg><use href="Content/icons.svg#edit" /></svg><span class="sr-only">Editar canción</span></asp:LinkButton><asp:LinkButton ID="btnDelete" runat="server" Visible='<%# IsAdmin %>' CommandName="DeleteSong" CommandArgument='<%# Eval("ID_SONG") %>' OnCommand="Song_Command" CssClass="icon-button delete-song" ToolTip="Eliminar canción" CausesValidation="false"><svg><use href="Content/icons.svg#trash" /></svg><span class="sr-only">Eliminar canción</span></asp:LinkButton></div>
                                </article>
                            </ItemTemplate></asp:Repeater>
                        </div>
                        <asp:Panel ID="pnlEmpty" runat="server" Visible="false" CssClass="empty-state"><svg><use href="Content/icons.svg#music" /></svg><h3>El próximo sonido empieza aquí</h3><p>Cuando el catálogo esté disponible, encontrarás aquí tus canciones.</p></asp:Panel>
                        <p id="noResults" class="empty-state" hidden>No encontramos canciones con esos filtros. Prueba otra búsqueda.</p>
                    </section>
                    <footer class="page-footer"><span class="brand-small">PoliMusic<span>.</span></span><span>La música nos conecta.</span><span>Hecho para disfrutar</span></footer>
                </div>
            </main>
        </div>

        <section class="player" aria-label="Reproductor de música">
            <div class="now-playing"><img id="playerCover" src="SongCovers/cover-1.svg" alt="Portada de la canción" /><div><strong id="playerTitle">Tu música te espera</strong><span id="playerArtist">Elige una canción para empezar</span></div><span id="playingBars" class="playing-bars" hidden><i></i><i></i><i></i></span></div>
            <div class="player-center"><div class="player-buttons"><button id="shuffleButton" type="button" class="icon-button" aria-label="Activar reproducción aleatoria" aria-pressed="false" disabled><svg><use href="Content/icons.svg#shuffle" /></svg></button><button id="previousButton" type="button" class="icon-button" aria-label="Canción anterior" disabled><svg><use href="Content/icons.svg#previous" /></svg></button><button id="playButton" type="button" class="player-toggle" aria-label="Reproducir" disabled><svg><use id="playIcon" href="Content/icons.svg#play" /></svg></button><button id="nextButton" type="button" class="icon-button" aria-label="Canción siguiente" disabled><svg><use href="Content/icons.svg#next" /></svg></button><button id="repeatButton" type="button" class="icon-button" aria-label="Repetir canción" aria-pressed="false" disabled><svg><use href="Content/icons.svg#repeat" /></svg></button></div><div class="progress-wrap"><span id="currentTime">0:00</span><input id="progress" type="range" min="0" max="100" value="0" step="0.1" aria-label="Posición de reproducción" disabled /><span id="duration">0:00</span></div></div>
            <div class="player-volume"><span class="quality-label">A TU RITMO</span><button id="muteButton" class="icon-button" type="button" aria-label="Silenciar"><svg><use id="volumeIcon" href="Content/icons.svg#volume" /></svg></button><input id="volume" type="range" min="0" max="1" step="0.01" value="0.7" aria-label="Volumen" /></div>
            <audio id="audioPlayer" preload="metadata"></audio>
        </section>
        <p id="playerStatus" class="sr-only" role="status" aria-live="polite"></p>
        <div id="playerToast" class="player-toast" role="status" hidden></div>

        <asp:Panel ID="pnlEditor" runat="server" Visible="false" CssClass="editor-backdrop">
            <section class="song-editor" role="dialog" aria-modal="true" aria-labelledby="lblEditorTitle"><span class="eyebrow">GESTIONAR CATÁLOGO</span><h2><asp:Label ID="lblEditorTitle" runat="server" /></h2><p>Comparte un nuevo sonido con tu comunidad.</p><asp:HiddenField ID="hidSongID" runat="server" /><div class="field"><asp:Label runat="server" AssociatedControlID="txtSongName" Text="Nombre de la canción" /><asp:TextBox ID="txtSongName" runat="server" MaxLength="50" placeholder="Escribe el título" /></div><div class="field"><asp:Label runat="server" AssociatedControlID="ddlAudioFiles" Text="Archivo de audio existente" /><asp:DropDownList ID="ddlAudioFiles" runat="server" /></div><div class="upload-field"><asp:Label runat="server" AssociatedControlID="fupSong" Text="O sube un nuevo MP3" /><asp:FileUpload ID="fupSong" runat="server" accept=".mp3,audio/mpeg" /><small>Formato MP3 · Máximo 50 MB. El archivo subido tiene prioridad.</small></div><asp:Label ID="lblEditorMessage" runat="server" CssClass="field-error" role="alert" /><div class="editor-actions"><asp:Button ID="btnCancel" runat="server" Text="Cancelar" CssClass="button ghost" OnClick="CancelSong_Click" CausesValidation="false" /><asp:Button ID="btnSave" runat="server" Text="Guardar canción" CssClass="button primary" OnClick="SaveSong_Click" /></div></section>
        </asp:Panel>
    </form>
</body>
</html>
