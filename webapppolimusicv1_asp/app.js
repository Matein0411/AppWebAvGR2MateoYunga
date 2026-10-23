(() => {
  "use strict";
  const byId = id => document.getElementById(id);
  const all = selector => [...document.querySelectorAll(selector)];
  const audio = byId("audio");
  if (!audio) return;
  const player = document.querySelector(".music-player");
  const expanded = byId("expanded-player");
  const isAdmin = document.body.dataset.admin === "true";
  const catalogError = document.body.dataset.catalogError === "true";
  const tracks = all("[data-track-index]").map(node => ({
    node, id: node.dataset.id, name: node.dataset.name, artist: node.dataset.artist,
    album: node.dataset.album, albumIds: node.dataset.albumIds.split(","),
    src: node.dataset.src, cover: node.dataset.cover, liked: node.dataset.liked === "true"
  }));
  const albums = new Map();
  const playlists = new Map();
  all("[data-album-id]").forEach(button => albums.set(button.dataset.albumId, { title: button.dataset.title }));
  all("[data-playlist-id]").forEach(button => playlists.set(button.dataset.playlistId, { title: button.dataset.title, ids: button.dataset.songIds.split(",") }));
  let route = { kind: "home", id: null };
  let current = -1;
  let playbackQueue = [];
  let shuffle = false;
  let loadVersion = 0;
  let listenTimer;
  let counted = false;
  let expandedOpener;
  let ownsFullscreen = false;
  const savingLikes = new Set();
  const normalize = text => text.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase("es");
  const formatTime = seconds => Number.isFinite(seconds) && seconds >= 0
    ? `${Math.floor(seconds / 60)}:${String(Math.floor(seconds % 60)).padStart(2, "0")}` : "0:00";
  const playable = indices => indices.filter(index => tracks[index]?.src);
  const allIndices = () => tracks.map((_, index) => index);
  const visibleQueue = () => playable(allIndices().filter(index => !tracks[index].node.hidden));
  const say = message => { byId("player-status").textContent = message; byId("expanded-status").textContent = message; };

  function syncLikes() {
    const count = tracks.filter(track => track.liked).length;
    all("[data-likes-count]").forEach(label => { label.textContent = String(count); });
    byId("likes-description").textContent = count === 1 ? "canción guardada por ti." : "canciones guardadas por ti.";
    all("[data-like-index], [data-like-current]").forEach(button => {
      const index = button.hasAttribute("data-like-current") ? current : Number(button.dataset.likeIndex);
      const track = tracks[index];
      button.disabled = !track || savingLikes.has(track.id);
      button.setAttribute("aria-pressed", String(!!track?.liked));
      button.setAttribute("aria-label", track ? `${track.liked ? "Quitar" : "Guardar"} ${track.name} ${track.liked ? "de" : "en"} Mis me gusta` : "Selecciona una canción para guardarla");
      button.setAttribute("aria-busy", String(!!track && savingLikes.has(track.id)));
    });
  }
  async function changeLike(index) {
    const track = tracks[index];
    if (!track || savingLikes.has(track.id)) return;
    savingLikes.add(track.id);
    syncLikes();
    try {
      const response = await fetch("me-gusta.asp", {
        method: "POST", credentials: "same-origin",
        body: new URLSearchParams({ csrf: player.dataset.csrf, id: track.id, liked: track.liked ? "0" : "1" })
      });
      const isJson = response.headers.get("content-type")?.includes("application/json");
      const result = isJson ? await response.json() : null;
      if (!response.ok || !result?.ok) throw new Error(result?.message || (response.redirected || response.status === 401 ? "Tu sesión venció. Vuelve a iniciar sesión para guardar canciones." : "No se pudo guardar el cambio. Actualiza la página e inténtalo de nuevo."));
      track.liked = result.liked;
      track.node.dataset.liked = String(track.liked);
      filterTracks();
      say(track.liked ? `${track.name} se guardó en Mis me gusta.` : `${track.name} se quitó de Mis me gusta.`);
    } catch (error) { say(error.message || "No se pudo conectar con tu biblioteca."); }
    finally { savingLikes.delete(track.id); syncLikes(); }
  }
  function parseRoute() {
    const hash = location.hash.slice(1);
    if (hash === "me-gusta") return { kind: "likes", id: null };
    if (hash === "albumes") return { kind: "albums", id: null };
    if (hash === "playlists") return { kind: "playlists", id: null };
    if (hash === "catalogo") return { kind: isAdmin ? "admin" : "search", id: null };
    if (hash === "gestionar-albumes") return { kind: isAdmin ? "adminAlbums" : "albums", id: null };
    if (hash === "buscar") return { kind: "search", id: null };
    const match = /^(album|playlist)\/(\d+)$/.exec(hash);
    if (match && (match[1] === "album" ? albums : playlists).has(match[2])) return { kind: match[1], id: match[2] };
    return { kind: "home", id: null };
  }
  function showRoute() {
    route = parseRoute();
    const isList = ["likes", "admin", "search", "album", "playlist"].includes(route.kind);
    const panel = isList ? "tracks" : route.kind;
    all("[data-view]").forEach(section => { section.hidden = section.dataset.view !== panel; });
    all("[data-nav]").forEach(link => {
      const active = link.dataset.nav === route.kind || (route.kind === "adminAlbums" && link.dataset.nav === "admin") || (route.kind === "album" && link.dataset.nav === "albums") || (route.kind === "playlist" && link.dataset.nav === "playlists");
      link.classList.toggle("active", active);
      if (active) link.setAttribute("aria-current", "page"); else link.removeAttribute("aria-current");
    });
    const title = {
      home: `Hola, ${document.body.dataset.username}.`, likes: "Mis me gusta", albums: "Álbumes",
      playlists: "Mis playlists", admin: "Gestionar catálogo", adminAlbums: "Gestionar álbumes", search: "Explorar canciones",
      album: albums.get(route.id)?.title, playlist: playlists.get(route.id)?.title
    }[route.kind];
    byId("page-title").textContent = title;
    byId("breadcrumb-title").textContent = route.kind === "home" ? "Inicio" : title;
    byId("page-eyebrow").textContent = { likes: "TU COLECCIÓN PERSONAL", admin: "ESPACIO DEL ADMINISTRADOR", adminAlbums: "ESPACIO DEL ADMINISTRADOR", playlist: "TU MÚSICA ORGANIZADA", playlists: "TU MÚSICA ORGANIZADA" }[route.kind] || "MÚSICA QUE VA CONTIGO";
    byId("page-subtitle").textContent = {
      home: "Encuentra el ritmo que va contigo.", likes: "Las canciones que quieres volver a escuchar.",
      albums: "Una portada, mil sensaciones.", playlists: "Las listas de tu cuenta, en un solo lugar.",
      admin: "Crea, edita y organiza las canciones del catálogo.", search: "Busca por canción, artista o álbum.",
      adminAlbums: "Dale una portada y una selección de canciones a cada álbum.",
      album: "Dale play a las canciones de este álbum.", playlist: "Dale play a las canciones de tu playlist."
    }[route.kind];
    byId("liked-intro").hidden = route.kind !== "likes";
    byId("list-title").textContent = route.kind === "likes" ? "Canciones guardadas" : route.kind === "admin" || route.kind === "search" ? "Catálogo de canciones" : "Canciones";
    all("[data-admin-action]").forEach(control => { control.hidden = route.kind !== "admin"; });
    document.body.classList.toggle("management-view", route.kind === "admin");
    if (byId("admin-tabs")) byId("admin-tabs").hidden = !["admin", "adminAlbums"].includes(route.kind);
    all("[data-admin-tab]").forEach(link => {
      if (link.dataset.adminTab === route.kind) link.setAttribute("aria-current", "page"); else link.removeAttribute("aria-current");
    });
    // Cambiar de sección no reconstruye el audio ni la cola de reproducción.
    if (route.kind !== "search") byId("search").value = "";
    filterTracks();
    syncLikes();
  }
  function filterTracks() {
    const search = normalize(byId("search").value.trim());
    if (isAdmin) {
      const rows = all("[data-admin-album]");
      rows.forEach(row => { row.hidden = !normalize(`${row.dataset.title} ${row.dataset.year}`).includes(search); });
      const visible = rows.filter(row => !row.hidden).length;
      byId("admin-album-count").textContent = String(visible);
      byId("admin-albums-empty").hidden = visible > 0 || catalogError;
    }
    let count = 0;
    tracks.forEach(track => {
      let visible = true;
      if (route.kind === "likes") visible = track.liked;
      if (route.kind === "album") visible = track.albumIds.includes(route.id);
      if (route.kind === "playlist") visible = playlists.get(route.id).ids.includes(track.id);
      if (search) visible = visible && normalize(`${track.name} ${track.artist} ${track.album}`).includes(search);
      track.node.hidden = !visible;
      if (visible) count += 1;
    });
    byId("song-count").textContent = String(count);
    byId("empty-state").hidden = count > 0 || catalogError;
    byId("empty-title").textContent = route.kind === "likes" && !search ? "Tu colección comienza contigo" : "No encontramos canciones";
    byId("empty-description").textContent = search ? "Prueba con otro nombre o quita la búsqueda." : route.kind === "likes" ? "Marca el corazón de una canción para guardarla aquí." : "Las canciones disponibles en esta colección aparecerán aquí.";
    byId("filter-info").hidden = !search;
    byId("filter-label").textContent = `${count} ${count === 1 ? "canción" : "canciones"} en tu búsqueda`;
    byId("play-collection").disabled = visibleQueue().length === 0;
  }
  function syncPlaying() {
    const playing = current >= 0 && !audio.paused && !audio.ended;
    all(".play-glyph").forEach(node => { node.hidden = playing; });
    all(".pause-glyph").forEach(node => { node.hidden = !playing; });
    byId("playing-bars").hidden = !playing;
    all('[data-control="toggle"]').forEach(button => {
      button.disabled = !tracks[current]?.src;
      button.setAttribute("aria-label", playing ? "Pausar" : "Reproducir");
    });
    all('[data-control="previous"], [data-control="next"]').forEach(button => { button.disabled = playbackQueue.length === 0; });
    all('[data-control="shuffle"]').forEach(button => button.setAttribute("aria-pressed", String(shuffle)));
    all('[data-control="repeat"]').forEach(button => button.setAttribute("aria-pressed", String(audio.loop)));
    tracks.forEach((track, index) => {
      track.node.classList.toggle("is-current", index === current);
      track.node.classList.toggle("is-playing", index === current && playing);
    });
    all("[data-play-index]").forEach(button => {
      const index = Number(button.dataset.playIndex);
      if (tracks[index]) button.setAttribute("aria-label", `${index === current && playing ? "Pausar" : "Reproducir"} ${tracks[index].name}`);
    });
  }
  function syncProgress() {
    const valid = Number.isFinite(audio.duration) && audio.duration > 0;
    all("[data-current-time]").forEach(node => { node.textContent = formatTime(audio.currentTime); });
    all("[data-duration]").forEach(node => { node.textContent = formatTime(audio.duration); });
    all("[data-seek]").forEach(input => { input.disabled = !valid; input.value = valid ? String(audio.currentTime / audio.duration * 100) : "0"; });
  }
  function selectTrack(index, queue) {
    const track = tracks[index];
    if (!track) return false;
    if (queue) playbackQueue = playable(queue);
    if (current !== index) {
      ++loadVersion;
      clearTimeout(listenTimer);
      counted = false;
      audio.pause();
      current = index;
      if (track.src) audio.src = new URL(track.src, location.href).href;
      else audio.removeAttribute("src");
      audio.load();
      byId("player-title").textContent = track.name;
      byId("player-artist").textContent = track.artist;
      byId("expanded-title").textContent = track.name;
      byId("expanded-artist").textContent = track.artist;
      [byId("player-cover"), byId("expanded-cover")].forEach(image => { image.src = track.cover; image.alt = `Portada de ${track.name}`; });
      syncProgress();
    }
    syncLikes();
    syncPlaying();
    return true;
  }
  async function play(index, queue) {
    if (!selectTrack(index, queue)) return;
    if (!tracks[index].src) { say("El archivo de audio de esta canción todavía no está disponible."); return; }
    say("");
    const version = ++loadVersion;
    try { await audio.play(); }
    catch (error) {
      if (version !== loadVersion || error.name === "AbortError") return;
      say(error.name === "NotAllowedError" ? "Pulsa reproducir para empezar a escuchar." : "No se pudo reproducir el audio. Comprueba que el MP3 esté disponible.");
      syncPlaying();
    }
  }
  function toggle() { if (current >= 0) { if (audio.paused || audio.ended) play(current); else audio.pause(); } }
  function advance(direction, wrap = true) {
    if (!playbackQueue.length) return;
    if (shuffle && playbackQueue.length > 1) {
      const options = playbackQueue.filter(index => index !== current);
      play(options[Math.floor(Math.random() * options.length)]);
      return;
    }
    const position = playbackQueue.indexOf(current);
    const next = position < 0 ? 0 : position + direction;
    if (!wrap && next >= playbackQueue.length) return;
    const index = playbackQueue[(next + playbackQueue.length) % playbackQueue.length];
    if (index === current && audio.ended) audio.currentTime = 0;
    play(index);
  }
  all("[data-play-index]").forEach(button => button.addEventListener("click", () => {
    const index = Number(button.dataset.playIndex);
    const queue = route.kind === "home" ? playable(allIndices()) : visibleQueue();
    if (index === current) { playbackQueue = queue; toggle(); } else play(index, queue);
  }));
  all("[data-control]").forEach(button => button.addEventListener("click", () => {
    switch (button.dataset.control) {
      case "toggle": toggle(); break;
      case "next": advance(1); break;
      case "previous": if (current >= 0 && audio.currentTime > 3) audio.currentTime = 0; else advance(-1); break;
      case "shuffle": shuffle = !shuffle; syncPlaying(); break;
      case "repeat": audio.loop = !audio.loop; syncPlaying(); break;
    }
  }));
  all("[data-like-index]").forEach(button => button.addEventListener("click", () => changeLike(Number(button.dataset.likeIndex))));
  all("[data-like-current]").forEach(button => button.addEventListener("click", () => changeLike(current)));
  byId("play-collection").addEventListener("click", () => { const queue = visibleQueue(); if (queue.length) play(queue[0], queue); });
  all("[data-album-id]").forEach(button => button.addEventListener("click", () => { location.hash = `album/${button.dataset.albumId}`; }));
  all("[data-playlist-id]").forEach(button => button.addEventListener("click", () => { location.hash = `playlist/${button.dataset.playlistId}`; }));
  byId("search").addEventListener("input", () => {
    if (!["search", "likes", "admin", "adminAlbums", "album", "playlist"].includes(route.kind)) {
      history.replaceState(null, "", "#buscar");
      showRoute();
    } else filterTracks();
  });
  byId("clear-filter").addEventListener("click", () => { byId("search").value = ""; filterTracks(); byId("search").focus(); });
  window.addEventListener("hashchange", showRoute);
  audio.volume = .75;
  all("[data-volume]").forEach(input => input.addEventListener("input", event => {
    audio.volume = Number(event.target.value);
    all("[data-volume]").forEach(other => { other.value = event.target.value; });
  }));
  all("[data-seek]").forEach(input => input.addEventListener("input", event => {
    if (Number.isFinite(audio.duration) && audio.duration > 0) audio.currentTime = Number(event.target.value) / 100 * audio.duration;
  }));
  audio.addEventListener("loadedmetadata", syncProgress);
  audio.addEventListener("timeupdate", syncProgress);
  audio.addEventListener("play", syncPlaying);
  audio.addEventListener("playing", () => {
    syncPlaying();
    clearTimeout(listenTimer);
    if (counted) return;
    const startedIndex = current;
    listenTimer = setTimeout(async () => {
      if (current !== startedIndex || audio.paused || audio.ended || counted) return;
      counted = true;
      try {
        const response = await fetch("reproduccion.asp", { method: "POST", credentials: "same-origin", body: new URLSearchParams({ csrf: player.dataset.csrf, id: tracks[startedIndex].id }) });
        if (!response.ok || !response.headers.get("content-type")?.includes("application/json")) return;
        const result = await response.json();
        if (result.counted) {
          const counter = tracks[startedIndex].node.querySelector(".track-plays");
          counter.textContent = String(Math.min(2147483647, Number(counter.textContent) + 1));
        }
      } catch { /* Registrar estadísticas no interrumpe la música. */ }
    }, 5000);
  });
  ["pause", "waiting", "ended", "error"].forEach(name => audio.addEventListener(name, () => { clearTimeout(listenTimer); syncPlaying(); }));
  audio.addEventListener("ended", () => advance(1, false));
  audio.addEventListener("error", () => { if (tracks[current]?.src) say("Este audio no está disponible. Prueba con otra canción."); });
  all("[data-open-player]").forEach(button => button.addEventListener("click", () => {
    const requested = button.dataset.openPlayer;
    const index = requested === "current" ? (current >= 0 ? current : Math.max(0, tracks.findIndex(track => track.src))) : Number(requested);
    if (!tracks[index]) return;
    expandedOpener = button;
    selectTrack(index, current === index ? undefined : playable(allIndices()));
    if (!tracks[index].src) say("El archivo de audio de esta canción todavía no está disponible."); else say("");
    expanded.showModal();
    document.body.classList.add("player-expanded");
    byId("close-expanded").focus();
  }));
  byId("close-expanded").addEventListener("click", () => expanded.close());
  byId("browser-fullscreen").hidden = !document.fullscreenEnabled;
  byId("browser-fullscreen").addEventListener("click", async () => {
    try {
      if (ownsFullscreen && document.fullscreenElement) await document.exitFullscreen();
      else if (!document.fullscreenElement) { await document.documentElement.requestFullscreen(); ownsFullscreen = true; }
    } catch { say("Puedes seguir usando el reproductor ampliado en esta ventana."); }
  });
  expanded.addEventListener("close", () => {
    document.body.classList.remove("player-expanded");
    if (ownsFullscreen && document.fullscreenElement) { ownsFullscreen = false; document.exitFullscreen().catch(() => {}); }
    expandedOpener?.focus();
  });
  document.addEventListener("fullscreenchange", () => {
    byId("browser-fullscreen").setAttribute("aria-pressed", String(!!document.fullscreenElement));
    byId("browser-fullscreen").setAttribute("aria-label", document.fullscreenElement ? "Salir de pantalla completa" : "Activar pantalla completa");
    if (ownsFullscreen && !document.fullscreenElement) { ownsFullscreen = false; if (expanded.open) expanded.close(); }
  });
  document.addEventListener("keydown", event => {
    if (event.target.closest("input, textarea, button, a, dialog, [contenteditable]")) return;
    if (event.key === "/") { event.preventDefault(); byId("search").focus(); }
    if (event.code === "Space" && current >= 0) { event.preventDefault(); toggle(); }
  });
  const deleteDialog = byId("delete-dialog");
  if (deleteDialog) {
    let opener;
    all("[data-delete-id]").forEach(button => button.addEventListener("click", () => {
      opener = button;
      byId("delete-song-id").value = button.dataset.deleteId;
      byId("delete-song-name").textContent = button.dataset.deleteName;
      deleteDialog.showModal();
      byId("cancel-delete").focus();
    }));
    byId("cancel-delete").addEventListener("click", () => deleteDialog.close());
    deleteDialog.addEventListener("click", event => { if (event.target === deleteDialog) deleteDialog.close(); });
    deleteDialog.addEventListener("close", () => opener?.focus());
  }
  const deleteAlbumDialog = byId("delete-album-dialog");
  if (deleteAlbumDialog) {
    let opener;
    all("[data-delete-album]").forEach(button => button.addEventListener("click", () => {
      opener = button;
      byId("delete-album-id").value = button.dataset.deleteAlbum;
      byId("delete-album-name").textContent = button.dataset.albumName;
      deleteAlbumDialog.showModal();
      byId("cancel-delete-album").focus();
    }));
    byId("cancel-delete-album").addEventListener("click", () => deleteAlbumDialog.close());
    deleteAlbumDialog.addEventListener("close", () => opener?.focus());
  }
  showRoute();
  syncPlaying();
})();
