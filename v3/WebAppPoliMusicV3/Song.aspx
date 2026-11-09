<%@ Page Title="Canciones" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Song.aspx.cs" Inherits="WebAppPoliMusicV3.Song" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <div id="music-library" class="music-library">
        <header class="topbar">
            <label class="search-box">
                <svg aria-hidden="true"><use href="<%: IconPath %>#search"></use></svg>
                <input id="song-search" type="search" placeholder="¿Qué quieres escuchar?"
                    aria-label="Buscar canción, artista o álbum" autocomplete="off" />
                <kbd aria-hidden="true">/</kbd>
            </label>
            <div class="profile">
                <div><strong><%: UserName %></strong><small>Tu cuenta</small></div>
                <img class="profile-avatar" src="<%: ProfilePhoto %>" alt="" width="36" height="36" />
            </div>
        </header>

        <asp:PlaceHolder ID="phHome" runat="server">
            <div class="welcome">
                <p class="eyebrow">Tu espacio musical</p>
                <h1>Hola, <%: UserName %><span class="brand-dot">.</span></h1>
            </div>
            <section class="hero" aria-labelledby="hero-title">
                <div class="hero-copy">
                    <p class="eyebrow"><span class="hero-dot"></span> Escucha a tu ritmo</p>
                    <h2 id="hero-title">Dale play<br />a tu día.</h2>
                    <p>Descubre una canción para cada momento y vuelve a escuchar tus favoritas.</p>
                    <div class="hero-actions">
                        <button id="hero-play" class="button primary" type="button" disabled>
                            <svg aria-hidden="true"><use href="<%: IconPath %>#play"></use></svg>Escuchar ahora
                        </button>
                        <a href="#canciones">Explorar catálogo <span aria-hidden="true">↗</span></a>
                    </div>
                </div>
                <div class="hero-art" aria-hidden="true">
                    <span class="record"></span>
                    <img src="~/SongCovers/cover-2.svg" alt="" runat="server" />
                </div>
            </section>

            <asp:PlaceHolder ID="phFeatured" runat="server">
                <section class="featured" aria-labelledby="featured-title">
                    <header class="section-heading">
                        <div><h2 id="featured-title">Encuentra tu ritmo</h2><p>Una selección de tu catálogo.</p></div>
                        <a href="#canciones" class="text-link">Ver canciones <span aria-hidden="true">→</span></a>
                    </header>
                    <div class="featured-grid">
                        <asp:Repeater ID="rptFeatured" runat="server">
                            <ItemTemplate>
                                <article class="song-card" data-card='<%# Eval("Index") %>'>
                                    <div class="card-art">
                                        <img src='<%#: Eval("CoverUrl") %>' alt="" width="256" height="256" />
                                        <asp:PlaceHolder runat="server" Visible='<%# (bool)Eval("HasAudio") %>'>
                                            <button class="track-play" type="button" data-play-track='<%# Eval("Index") %>'
                                                aria-label='<%#: "Reproducir " + Eval("Name") %>' aria-pressed="false">
                                                <svg aria-hidden="true"><use href="<%# IconPath %>#play"></use></svg>
                                            </button>
                                        </asp:PlaceHolder>
                                    </div>
                                    <h3><%#: Eval("Name") %></h3>
                                    <p><%#: Eval("Artist") %></p>
                                    <span class='card-status <%# (bool)Eval("HasAudio") ? "available" : "" %>'>
                                        <%# (bool)Eval("HasAudio") ? "Disponible para escuchar" : "Audio no disponible" %>
                                    </span>
                                </article>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                </section>
            </asp:PlaceHolder>
        </asp:PlaceHolder>

        <section id="canciones" class="catalog" aria-labelledby="catalog-title">
            <header class="section-heading">
                <div>
                    <p class="eyebrow">Tu colección</p>
                    <asp:PlaceHolder ID="phHomeHeading" runat="server"><h2 id="catalog-title">Todas las canciones</h2></asp:PlaceHolder>
                    <asp:PlaceHolder ID="phCatalogHeading" runat="server"><h1 id="catalog-title">Todas las canciones</h1></asp:PlaceHolder>
                    <asp:Label ID="lblSongCount" runat="server" CssClass="section-caption" />
                </div>
            </header>
            <asp:Label ID="lblCatalogError" runat="server" CssClass="message" role="alert" />
            <asp:GridView ID="grdSongs" runat="server" AutoGenerateColumns="false" GridLines="None"
                CssClass="track-grid" UseAccessibleHeader="true" EnableViewState="false">
                <Columns>
                    <asp:TemplateField HeaderText="Reproducir" ItemStyle-CssClass="track-control">
                        <ItemTemplate>
                            <asp:PlaceHolder runat="server" Visible='<%# (bool)Eval("HasAudio") %>'>
                                <button type="button" class="track-play" data-play-track='<%# Eval("Index") %>'
                                    aria-label='<%#: "Reproducir " + Eval("Name") %>' aria-pressed="false">
                                    <svg aria-hidden="true"><use href="<%# IconPath %>#play"></use></svg>
                                </button>
                            </asp:PlaceHolder>
                            <asp:PlaceHolder runat="server" Visible='<%# !(bool)Eval("HasAudio") %>'>
                                <span class="unavailable">Sin audio</span>
                            </asp:PlaceHolder>
                        </ItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="Título">
                        <ItemTemplate>
                            <div class="track-identity" data-song='<%# Eval("Index") %>' data-audio='<%#: Eval("AudioUrl") %>'>
                                <img src='<%#: Eval("CoverUrl") %>' alt="" width="40" height="40" loading="lazy" />
                                <div><strong><%#: Eval("Name") %></strong><span><%#: Eval("Artist") %></span></div>
                            </div>
                        </ItemTemplate>
                    </asp:TemplateField>
                    <asp:BoundField DataField="Album" HeaderText="Álbum" ItemStyle-CssClass="track-album" HeaderStyle-CssClass="track-album" />
                </Columns>
                <EmptyDataTemplate>
                    <p class="empty-state">Todavía no hay canciones en el catálogo.</p>
                </EmptyDataTemplate>
            </asp:GridView>
            <p id="search-empty" class="empty-state" role="status" hidden>No encontramos canciones para esa búsqueda.</p>
        </section>
    </div>

    <section class="player" aria-label="Reproductor de música">
        <div class="now-playing">
            <img id="player-cover" src="<%: ResolveUrl("~/SongCovers/cover-1.svg") %>" alt="" width="48" height="48" />
            <div class="player-copy" aria-live="polite">
                <strong id="player-title">Tu música te espera</strong>
                <span id="player-status">Elige una canción para empezar.</span>
            </div>
        </div>
        <div class="player-center">
            <div class="player-controls">
                <button id="player-previous" class="player-button" type="button" aria-label="Canción anterior" disabled>
                    <svg aria-hidden="true"><use href="<%: IconPath %>#previous"></use></svg>
                </button>
                <button id="player-toggle" class="player-button player-toggle" type="button" aria-label="Reproducir" disabled>
                    <svg class="play-icon" aria-hidden="true"><use href="<%: IconPath %>#play"></use></svg>
                    <svg class="pause-icon" aria-hidden="true"><use href="<%: IconPath %>#pause"></use></svg>
                </button>
                <button id="player-next" class="player-button" type="button" aria-label="Canción siguiente" disabled>
                    <svg aria-hidden="true"><use href="<%: IconPath %>#next"></use></svg>
                </button>
                <button id="player-repeat" class="player-button" type="button" aria-label="Repetir canción" aria-pressed="false" disabled>
                    <svg aria-hidden="true"><use href="<%: IconPath %>#repeat"></use></svg>
                </button>
            </div>
            <div class="player-progress">
                <span id="player-elapsed">0:00</span>
                <input id="player-position" type="range" min="0" max="1" value="0" step="0.1" aria-label="Posición de reproducción" disabled />
                <span id="player-duration">0:00</span>
            </div>
        </div>
        <div class="player-volume">
            <button id="player-mute" class="player-button" type="button" aria-label="Silenciar" aria-pressed="false">
                <svg class="volume-icon" aria-hidden="true"><use href="<%: IconPath %>#volume"></use></svg>
                <svg class="mute-icon" aria-hidden="true"><use href="<%: IconPath %>#muted"></use></svg>
            </button>
            <input id="player-volume" type="range" min="0" max="1" step="0.01" value="0.7" aria-label="Volumen" />
        </div>
        <audio id="catalog-audio" preload="metadata"></audio>
    </section>

    <script>
        "use strict";

        const library = document.getElementById("music-library");
        const audio = document.getElementById("catalog-audio");
        const search = document.getElementById("song-search");
        const catalog = document.getElementById("canciones");
        const featured = library.querySelector(".featured");
        const noResults = document.getElementById("search-empty");

        const heroPlay = document.getElementById("hero-play");
        const cover = document.getElementById("player-cover");
        const title = document.getElementById("player-title");
        const status = document.getElementById("player-status");
        const toggle = document.getElementById("player-toggle");
        const previous = document.getElementById("player-previous");
        const next = document.getElementById("player-next");
        const repeat = document.getElementById("player-repeat");
        const position = document.getElementById("player-position");
        const elapsed = document.getElementById("player-elapsed");
        const duration = document.getElementById("player-duration");
        const mute = document.getElementById("player-mute");
        const volume = document.getElementById("player-volume");

        const cards = new Map(Array.from(library.querySelectorAll("[data-card]"), (card) => [card.dataset.card, card]));
        const playButtons = Array.from(library.querySelectorAll("[data-play-track]"));
        const tracks = Array.from(library.querySelectorAll("[data-song]"), (identity) => {
            const row = identity.closest("tr");
            const name = identity.querySelector("strong").textContent;
            const artist = identity.querySelector("span").textContent;
            const album = row.querySelector(".track-album").textContent;
            return {
                index: identity.dataset.song,
                name,
                artist,
                cover: identity.querySelector("img").src,
                audioUrl: identity.dataset.audio,
                searchText: normalize(name + " " + artist + " " + album),
                row,
                card: cards.get(identity.dataset.song)
            };
        });

        const playable = tracks.filter((track) => track.audioUrl);
        let selected = null;

        function normalize(value) {
            return value.toLocaleLowerCase("es").normalize("NFD").replace(/[\u0300-\u036f]/g, "");
        }

        function filterCatalog() {
            const query = normalize(search.value).trim();
            let matches = 0;
            let featuredMatches = 0;
            tracks.forEach((track) => {
                const visible = track.searchText.includes(query);
                track.row.hidden = !visible;
                if (visible) matches++;
                if (track.card) {
                    track.card.hidden = !visible;
                    if (visible) featuredMatches++;
                }
            });
            if (featured) featured.hidden = featuredMatches === 0;
            noResults.hidden = tracks.length === 0 || matches !== 0;
        }

        function syncPlayback() {
            const playing = selected !== null && !audio.paused && !audio.ended;
            toggle.dataset.playing = String(playing);
            toggle.setAttribute("aria-label", playing ? "Pausar" : "Reproducir");

            const selectedIndex = playable.indexOf(selected);
            previous.disabled = selectedIndex <= 0;
            next.disabled = selectedIndex < 0 || selectedIndex >= playable.length - 1;

            playButtons.forEach((button) => {
                button.setAttribute("aria-pressed", String(playing && selected.index === button.dataset.playTrack));
            });
        }

        function formatTime(seconds) {
            const total = Math.floor(seconds);
            return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0");
        }

        function syncProgress() {
            const hasDuration = Number.isFinite(audio.duration) && audio.duration > 0;
            position.disabled = !hasDuration;
            position.max = hasDuration ? audio.duration : 1;
            position.value = hasDuration ? audio.currentTime : 0;
            elapsed.textContent = formatTime(audio.currentTime);
            duration.textContent = hasDuration ? formatTime(audio.duration) : "0:00";
        }

        async function playTrack(track) {
            if (track !== selected) {
                if (selected) selected.row.classList.remove("current-track");
                selected = track;
                track.row.classList.add("current-track");
                title.textContent = track.name;
                cover.src = track.cover;
                audio.src = track.audioUrl;
                syncProgress();
            }

            status.textContent = track.artist;
            try {
                await audio.play();
            } catch (error) {
                if (selected === track && error.name !== "AbortError") {
                    status.textContent = "No se pudo reproducir el audio.";
                }
            }
            syncPlayback();
        }

        function toggleTrack(track) {
            if (!track) return;
            if (track === selected && !audio.paused) {
                audio.pause();
                syncPlayback();
                return;
            }
            playTrack(track);
        }

        function syncVolume() {
            mute.setAttribute("aria-pressed", String(audio.muted));
            mute.setAttribute("aria-label", audio.muted ? "Activar sonido" : "Silenciar");
            volume.value = audio.volume;
        }

        search.addEventListener("input", filterCatalog);
        search.addEventListener("keydown", (event) => {
            if (event.key === "Enter") {
                event.preventDefault();
                catalog.scrollIntoView();
            }
        });

        document.querySelector("[data-find-song]").addEventListener("click", (event) => {
            event.preventDefault();
            search.focus();
        });
        document.querySelector("[data-show-catalog]").addEventListener("click", (event) => {
            event.preventDefault();
            catalog.scrollIntoView();
        });
        document.addEventListener("keydown", (event) => {
            if (event.key === "/" && !event.ctrlKey && !event.metaKey && !event.altKey &&
                !event.target.matches("input, textarea, select") && !event.target.isContentEditable) {
                event.preventDefault();
                search.focus();
            }
        });

        playButtons.forEach((button) => {
            button.addEventListener("click", () => {
                const track = playable.find((item) => item.index === button.dataset.playTrack);
                toggleTrack(track);
            });
        });

        if (heroPlay) {
            heroPlay.disabled = playable.length === 0;
            heroPlay.addEventListener("click", () => playTrack(playable[0]));
        }
        toggle.disabled = playable.length === 0;
        repeat.disabled = playable.length === 0;
        audio.volume = Number(volume.value);

        toggle.addEventListener("click", () => toggleTrack(selected || playable[0]));
        previous.addEventListener("click", () => playTrack(playable[playable.indexOf(selected) - 1]));
        next.addEventListener("click", () => playTrack(playable[playable.indexOf(selected) + 1]));
        repeat.addEventListener("click", () => {
            audio.loop = !audio.loop;
            repeat.setAttribute("aria-pressed", String(audio.loop));
        });
        position.addEventListener("input", () => { audio.currentTime = Number(position.value); });
        mute.addEventListener("click", () => { audio.muted = !audio.muted; });
        volume.addEventListener("input", () => {
            audio.volume = Number(volume.value);
            audio.muted = false;
        });

        ["play", "pause", "error"].forEach((event) => audio.addEventListener(event, syncPlayback));
        ["durationchange", "timeupdate", "emptied"].forEach((event) => audio.addEventListener(event, syncProgress));
        audio.addEventListener("volumechange", syncVolume);
        audio.addEventListener("ended", () => {
            const following = playable[playable.indexOf(selected) + 1];
            if (following) playTrack(following);
            else syncPlayback();
        });
    </script>
</asp:Content>

<asp:Content ID="SongHead" ContentPlaceHolderID="PageHead" runat="server">
    <style>
        .music-library { width: min(100%, 86rem); margin-inline: auto; padding: 1rem clamp(1.15rem, 4vw, 3.25rem) 2.25rem; }
        .topbar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 1.1rem;
            margin-bottom: clamp(1.35rem, 2.2vw, 1.9rem);
        }

        .search-box {
            display: flex;
            align-items: center;
            gap: .6rem;
            width: min(100%, 24rem);
            min-width: 0;
            padding: .58rem .75rem;
            border: 1px solid var(--line);
            border-radius: 999px;
            background: var(--surface);
            color: var(--muted);
        }

        .search-box:focus-within { border-color: var(--rose); box-shadow: 0 0 0 2px var(--rose-tint); }
        .search-box input { min-width: 0; width: 100%; border: 0; outline: 0; background: transparent; color: var(--ink); font-size: .87rem; }
        .search-box input::placeholder { color: var(--muted); }
        .search-box kbd { border: 1px solid var(--line); border-radius: .25rem; padding: 0 .32rem; }
        .profile small { display: block; margin-top: .18rem; color: var(--muted); font-size: .73rem; }
        .profile { display: flex; align-items: center; gap: .55rem; text-align: right; font-size: .85rem; }
        .profile strong { display: block; max-width: 12rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .profile-avatar {
            width: 2.25rem;
            height: 2.25rem;
            flex-shrink: 0;
            object-fit: cover;
            border-radius: 50%;
            background: var(--rose-tint);
        }

        .welcome { margin-bottom: 1rem; }

        .welcome h1, .section-heading h1 {
            margin: .28rem 0 0;
            font-size: clamp(1.7rem, 4vw, 2.25rem);
            line-height: 1.14;
            letter-spacing: -.05em;
            overflow-wrap: anywhere;
        }

        .hero {
            position: relative;
            isolation: isolate;
            display: grid;
            grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr);
            align-items: center;
            gap: 1rem;
            min-height: 16rem;
            padding: clamp(1.4rem, 3vw, 2.1rem) clamp(1.4rem, 4vw, 3.1rem);
            overflow: hidden;
            border-radius: 1rem;
            background: radial-gradient(ellipse at 100% -10%, #f5788e88, transparent 62%),
                linear-gradient(112deg, #83143d 2%, #a41b4b 57%, #cd395c);
            color: white;
        }

        .hero-copy { position: relative; z-index: 1; }
        .hero .eyebrow { color: #ffe2e9; }
        .hero-dot {
            display: inline-block;
            width: .42rem;
            height: .42rem;
            margin-right: .22rem;
            border-radius: 50%;
            background: #ff8fa6;
        }

        .hero h2 {
            margin: .65rem 0;
            font-size: clamp(2.4rem, 5vw, 3.65rem);
            line-height: .98;
            letter-spacing: -.06em;
        }

        .hero-copy > p:not(.eyebrow) {
            max-width: 24rem;
            margin: 0;
            color: #ffedf2;
            font-size: .95rem;
            line-height: 1.5;
        }

        .hero-actions { display: flex; flex-wrap: wrap; align-items: center; gap: .85rem 1.1rem; margin-top: 1.15rem; }
        .hero-actions a { font-size: .84rem; font-weight: 700; }
        .hero-actions a:hover { text-decoration: underline; }
        .hero :focus-visible { outline-color: white; }
        .hero-art { position: relative; width: min(100%, 17rem); aspect-ratio: 1.3; justify-self: center; }
        .hero-art img {
            position: absolute;
            inset: 3% auto auto 1%;
            width: 75%;
            height: auto;
            border-radius: .55rem;
            transform: rotate(-9deg);
            box-shadow: 0 1.4rem 2.8rem #360e2b5c;
        }

        .record {
            position: absolute;
            top: 3%;
            right: 0;
            width: 75%;
            aspect-ratio: 1;
            border: 1px solid #ffffff40;
            border-radius: 50%;
            background: repeating-radial-gradient(circle, #2e192b 0 2px, #231421 2px 4px);
            box-shadow: 0 1.3rem 2rem #300e2580;
        }

        .record::after {
            position: absolute;
            inset: 36%;
            content: "";
            border-radius: 50%;
            background: radial-gradient(circle, #30202d 0 9%, #f07590 10% 100%);
        }

        .hero .button.primary { background: white; color: var(--rose-dark); }
        .hero .button.primary:hover { background: #ffe8ee; }

        .featured, .catalog { margin-top: 1.8rem; }
        .catalog { scroll-margin-top: .8rem; }
        .section-heading { display: flex; justify-content: space-between; align-items: end; gap: .9rem; margin-bottom: .85rem; }
        .section-heading h2 { margin: .18rem 0 0; font-size: clamp(1.18rem, 2.5vw, 1.46rem); letter-spacing: -.035em; }
        .section-heading p:not(.eyebrow), .section-caption { display: block; margin: .25rem 0 0; color: var(--muted); font-size: .86rem; }
        .text-link { color: var(--rose-dark); font-size: .85rem; font-weight: 700; white-space: nowrap; }
        .text-link:hover { text-decoration: underline; }

        .featured-grid { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: clamp(.6rem, 1.3vw, 1rem); }
        .song-card {
            min-width: 0;
            padding: .65rem;
            border: 1px solid var(--line);
            border-radius: .78rem;
            background: var(--surface);
            box-shadow: 0 .25rem .7rem #3b203807;
        }

        .card-art { position: relative; }
        .card-art img { display: block; width: 100%; height: auto; aspect-ratio: 1; border-radius: .5rem; }
        .song-card h3 { margin: .65rem 0 0; font-size: .92rem; overflow-wrap: anywhere; }
        .song-card p { margin: .2rem 0; color: var(--muted); font-size: .8rem; }
        .card-status { display: block; margin-top: .45rem; color: var(--muted); font-size: .72rem; }
        .card-status.available { color: var(--rose-dark); font-weight: 650; }

        .track-play {
            display: grid;
            place-items: center;
            width: 2.15rem;
            height: 2.15rem;
            padding: 0;
            border: 0;
            border-radius: 50%;
            background: var(--rose-tint);
            color: var(--rose-dark);
        }

        .track-play:hover, .track-play[aria-pressed="true"] { background: var(--rose); color: white; }
        .card-art .track-play {
            position: absolute;
            right: .5rem;
            bottom: .5rem;
            background: var(--rose);
            color: white;
            box-shadow: 0 .25rem .7rem #38102754;
        }

        .card-art .track-play:hover { background: var(--rose-dark); }
        .track-play[aria-pressed="true"] svg { display: none; }
        .track-play[aria-pressed="true"]::after {
            width: .72rem;
            height: .78rem;
            border-inline: .23rem solid currentColor;
            content: "";
        }

        .track-grid { width: 100%; border-collapse: collapse; }
        .track-grid th, .track-grid td { padding: .55rem .72rem; border-bottom: 1px solid var(--line); text-align: left; overflow-wrap: anywhere; }
        .track-grid th { color: var(--muted); font-size: .78rem; font-weight: 650; }
        .track-grid tbody tr:hover, .track-grid .current-track { background: #f8edf1; }
        .track-control { width: 6rem; }
        .track-identity { display: flex; align-items: center; gap: .7rem; }
        .track-identity img { flex: 0 0 auto; border-radius: .36rem; }
        .track-identity span { display: block; margin-top: .15rem; color: var(--muted); font-size: .83rem; }
        .track-album, .unavailable, .empty-state { color: var(--muted); font-size: .84rem; }

        .player {
            position: fixed;
            z-index: 2;
            inset: auto 0 0;
            display: grid;
            grid-template-columns: minmax(0, 1fr) minmax(13rem, 2fr) minmax(0, 1fr);
            align-items: center;
            gap: 1rem;
            min-height: var(--player-height);
            padding: .5rem clamp(1rem, 3vw, 2rem) max(.5rem, env(safe-area-inset-bottom));
            border-top: 1px solid var(--line);
            background: #fffffff2;
            backdrop-filter: blur(18px);
            box-shadow: 0 -.25rem 1.2rem #3415260b;
        }

        .now-playing { display: flex; align-items: center; gap: .7rem; min-width: 0; }
        .now-playing img { flex: 0 0 auto; border-radius: .45rem; }
        .player-copy { display: grid; gap: .12rem; min-width: 0; font-size: .88rem; }
        .player-copy > * { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .player-copy span { color: var(--muted); font-size: .75rem; }
        .player-center { width: min(100%, 38rem); justify-self: center; }
        .player-controls, .player-progress, .player-volume { display: flex; align-items: center; }
        .player-controls { justify-content: center; gap: .45rem; }
        .player-button {
            display: grid;
            place-items: center;
            width: 2rem;
            height: 2rem;
            padding: 0;
            border: 0;
            border-radius: 50%;
            background: transparent;
            color: var(--muted);
        }

        .player-button:not(:disabled):hover, .player-button[aria-pressed="true"] { background: var(--rose-tint); color: var(--rose-dark); }
        .player-button:disabled { opacity: .45; }
        .player-button.player-toggle { width: 2.35rem; height: 2.35rem; background: var(--rose); color: white; }
        .player-button.player-toggle:not(:disabled):hover { background: var(--rose-dark); color: white; }
        .player-toggle .pause-icon, .player-toggle[data-playing="true"] .play-icon, #player-mute .mute-icon, #player-mute[aria-pressed="true"] .volume-icon { display: none; }
        .player-toggle[data-playing="true"] .pause-icon, #player-mute[aria-pressed="true"] .mute-icon { display: block; }

        .player-progress { gap: .45rem; margin-top: .16rem; color: var(--muted); font-size: .69rem; font-variant-numeric: tabular-nums; }
        .player-progress span { min-width: 2rem; text-align: center; }
        .player input[type="range"] { min-width: 0; height: 1rem; margin: 0; accent-color: var(--rose); }
        .player-progress input { flex: 1; }
        .player-volume { justify-content: flex-end; gap: .35rem; }
        .player-volume input { width: min(52%, 6.5rem); }

        @media (max-width: 1000px) { .featured-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); } }

        @media (max-width: 720px) {
            .music-library { padding-inline: 1rem; }
            .topbar { gap: .7rem; margin-bottom: 1.35rem; }
            .profile div, .search-box kbd { display: none; }
            .hero { grid-template-columns: minmax(0, 1.3fr) minmax(0, .7fr); min-height: 13rem; padding: 1.12rem; }
            .hero h2 { font-size: clamp(2.1rem, 9vw, 3.5rem); }
            .hero-copy > p:not(.eyebrow) { font-size: .84rem; }
            .hero-actions { gap: .6rem; }
            .hero-actions a { font-size: .77rem; }
            .featured-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
            .player { grid-template-columns: minmax(0, 1fr) auto; gap: .3rem .65rem; padding-top: .55rem; }
            .player-center { grid-column: 1 / -1; grid-row: 2; }
            .player-volume { grid-column: 2; grid-row: 1; }
            .player-volume input { width: 3.5rem; }
            .now-playing img { width: 2.3rem; height: 2.3rem; }
        }

        @media (max-width: 440px) {
            .featured-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
            .track-grid th, .track-grid td { padding-inline: .4rem; }
            .track-control { width: 5.3rem; }
            .track-grid .track-album { display: none; }
        }

        @media (max-width: 350px) {
            .hero { grid-template-columns: minmax(0, 1fr); }
            .hero-art { display: none; }
        }
    </style>
</asp:Content>
