/* The catalog is rendered by Web Forms. Only filtering and audio playback happen here. */
(() => {
    'use strict';
    const byId = id => document.getElementById(id);
    const audio = byId('audioPlayer');
    const list = byId('songList');
    const rows = Array.from(list.querySelectorAll('.song-row'));
    const songs = rows.map((row, index) => ({ ...row.dataset, row, index }));
    const search = byId('songSearch');
    const progress = byId('progress');
    const volume = byId('volume');
    const playButton = byId('playButton');
    let filter = 'all';
    let current = null;
    let queue = [];
    let shuffled = false;
    let repeat = false;
    let listenTimer = null;
    let toastTimer = null;
    let playRegistered = false;

    const formatTime = value => Number.isFinite(value) ? `${Math.floor(value / 60)}:${String(Math.floor(value % 60)).padStart(2, '0')}` : '0:00';
    const paintRange = (input, percent) => input.style.setProperty('--progress', `${percent}%`);
    const announce = text => { byId('playerStatus').textContent = text; };
    function toast(text) {
        byId('playerToast').textContent = text;
        byId('playerToast').hidden = false;
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => { byId('playerToast').hidden = true; }, 4500);
    }
    function filterSongs() {
        const term = search.value.trim().toLocaleLowerCase();
        const sorted = [...songs].sort((a, b) => filter === 'popular' ? Number(b.plays) - Number(a.plays) || a.index - b.index : a.index - b.index);
        let count = 0;
        sorted.forEach(song => {
            const matches = `${song.name} ${song.artist} ${song.album}`.toLocaleLowerCase().includes(term);
            song.row.hidden = !matches || (filter === 'available' && !song.audio);
            if (!song.row.hidden) count++;
            list.appendChild(song.row);
        });
        byId('noResults').hidden = songs.length === 0 || count > 0;
        const title = { all: 'Todas las canciones', available: 'Listas para sonar', popular: 'Las más escuchadas' };
        byId('catalogTitle').textContent = title[filter];
        document.querySelectorAll('.chip').forEach(chip => {
            const active = chip.dataset.filter === filter;
            chip.classList.toggle('active', active);
            chip.setAttribute('aria-pressed', String(active));
        });
    }
    document.querySelectorAll('[data-filter]').forEach(button => button.addEventListener('click', () => {
        filter = button.dataset.filter;
        filterSongs();
        if (button.classList.contains('library-item')) byId('canciones').scrollIntoView({ behavior: 'smooth' });
    }));
    search.addEventListener('input', filterSongs);
    byId('navSearch').addEventListener('click', () => { search.focus(); window.scrollTo({ top: 0, behavior: 'smooth' }); });

    function updatePlaying() {
        const playing = current && !audio.paused;
        byId('playIcon').setAttribute('href', `Content/icons.svg#${playing ? 'pause' : 'play'}`);
        playButton.setAttribute('aria-label', playing ? 'Pausar' : 'Reproducir');
        byId('playingBars').hidden = !playing;
        rows.forEach(row => {
            const active = current && row.dataset.id === current.id;
            row.classList.toggle('is-current', !!active);
            const button = row.querySelector('.row-play');
            button.querySelector('use').setAttribute('href', `Content/icons.svg#${active && playing ? 'pause' : 'play'}`);
            button.setAttribute('aria-label', `${active && playing ? 'Pausar' : 'Reproducir'} ${row.dataset.name}`);
        });
        document.querySelectorAll('.card-play').forEach(button => {
            const song = songs.find(song => song.id === button.dataset.playId);
            const playingHere = playing && current.id === button.dataset.playId;
            button.querySelector('use').setAttribute('href', `Content/icons.svg#${playingHere ? 'pause' : 'play'}`);
            button.setAttribute('aria-label', `${playingHere ? 'Pausar' : 'Reproducir'} ${song ? song.name : ''}`);
        });
    }
    function attemptPlay() {
        const result = audio.play();
        if (result) result.catch(() => { toast('No se pudo reproducir este audio. Prueba otra canción.'); updatePlaying(); });
    }
    function startSong(song, freshQueue = true) {
        if (!song || !song.audio) return;
        if (current && current.id === song.id) { audio.paused ? attemptPlay() : audio.pause(); return; }
        if (freshQueue) {
            queue = Array.from(list.querySelectorAll('.song-row:not([hidden])')).map(row => songs.find(song => song.id === row.dataset.id)).filter(song => song.audio);
            if (!queue.some(item => item.id === song.id)) queue = songs.filter(item => item.audio);
        }
        current = song;
        playRegistered = false;
        clearTimeout(listenTimer);
        byId('playerTitle').textContent = song.name;
        byId('playerArtist').textContent = song.artist;
        byId('playerCover').src = song.cover;
        byId('playerCover').alt = `Portada de ${song.name}`;
        progress.value = 0;
        paintRange(progress, 0);
        byId('currentTime').textContent = '0:00';
        byId('duration').textContent = '0:00';
        ['playButton', 'previousButton', 'nextButton', 'shuffleButton', 'repeatButton'].forEach(id => { byId(id).disabled = false; });
        audio.src = song.audio;
        audio.load();
        attemptPlay();
        updatePlaying();
        announce(`Reproduciendo ${song.name}, ${song.artist}`);
    }
    function changeSong(direction) {
        if (!current || queue.length === 0) return;
        if (direction < 0 && audio.currentTime > 3) { audio.currentTime = 0; return; }
        const position = queue.findIndex(song => song.id === current.id);
        let next = (position + direction + queue.length) % queue.length;
        if (shuffled && queue.length > 1) {
            do { next = Math.floor(Math.random() * queue.length); } while (next === position);
        }
        if (queue[next].id === current.id) { audio.currentTime = 0; attemptPlay(); }
        else startSong(queue[next], false);
    }
    document.querySelectorAll('[data-play-id]').forEach(button => button.addEventListener('click', () => startSong(songs.find(song => song.id === button.dataset.playId))));
    byId('heroPlay').disabled = !songs.some(song => song.audio);
    byId('heroPlay').addEventListener('click', () => {
        const visible = songs.find(song => !song.row.hidden && song.audio);
        if (visible) startSong(visible); else toast('No hay audios disponibles con estos filtros.');
    });
    playButton.addEventListener('click', () => { if (current) audio.paused ? attemptPlay() : audio.pause(); });
    byId('previousButton').addEventListener('click', () => changeSong(-1));
    byId('nextButton').addEventListener('click', () => changeSong(1));
    byId('shuffleButton').addEventListener('click', event => {
        shuffled = !shuffled;
        event.currentTarget.classList.toggle('active', shuffled);
        event.currentTarget.setAttribute('aria-pressed', String(shuffled));
    });
    byId('repeatButton').addEventListener('click', event => {
        repeat = !repeat;
        event.currentTarget.classList.toggle('active', repeat);
        event.currentTarget.setAttribute('aria-pressed', String(repeat));
        audio.loop = repeat;
    });
    function scheduleListen() {
        clearTimeout(listenTimer);
        if (playRegistered || !current) return;
        const expectedID = current.id;
        listenTimer = setTimeout(async () => {
            if (!current || current.id !== expectedID || audio.paused || audio.seeking || audio.readyState < 3) return;
            playRegistered = true;
            try {
                const response = await fetch('Song.aspx', {
                    method: 'POST', credentials: 'same-origin',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: new URLSearchParams({ action: 'play', id: expectedID, csrf: document.querySelector('[name=csrf]').value })
                });
                const result = await response.json();
                if (result.saved) {
                    const song = songs.find(item => item.id === expectedID);
                    song.plays = String(Number(song.plays) + 1);
                    song.row.dataset.plays = song.plays;
                    song.row.querySelector('.play-count').textContent = Number(song.plays).toLocaleString('es');
                }
            } catch (_) { /* Audio remains usable if the statistics service is unavailable. */ }
        }, 5000);
    }
    audio.addEventListener('play', updatePlaying);
    audio.addEventListener('playing', scheduleListen);
    ['pause', 'waiting', 'seeking', 'ended'].forEach(name => audio.addEventListener(name, () => clearTimeout(listenTimer)));
    audio.addEventListener('pause', updatePlaying);
    audio.addEventListener('ended', () => { updatePlaying(); if (!repeat) changeSong(1); });
    audio.addEventListener('error', () => { toast('El archivo de audio no está disponible. Selecciona otra canción.'); updatePlaying(); });
    audio.addEventListener('loadedmetadata', () => {
        byId('duration').textContent = formatTime(audio.duration);
        progress.disabled = !Number.isFinite(audio.duration) || audio.duration <= 0;
    });
    audio.addEventListener('timeupdate', () => {
        byId('currentTime').textContent = formatTime(audio.currentTime);
        const percent = Number.isFinite(audio.duration) && audio.duration > 0 ? (audio.currentTime / audio.duration) * 100 : 0;
        progress.value = percent;
        paintRange(progress, percent);
    });
    progress.addEventListener('input', () => {
        if (Number.isFinite(audio.duration)) audio.currentTime = (Number(progress.value) / 100) * audio.duration;
    });
    audio.volume = Number(volume.value);
    paintRange(volume, audio.volume * 100);
    function updateVolume() {
        const muted = audio.muted || audio.volume === 0;
        byId('volumeIcon').setAttribute('href', `Content/icons.svg#${muted ? 'muted' : 'volume'}`);
        byId('muteButton').setAttribute('aria-label', muted ? 'Activar sonido' : 'Silenciar');
        paintRange(volume, muted ? 0 : audio.volume * 100);
    }
    volume.addEventListener('input', () => { audio.volume = Number(volume.value); audio.muted = false; updateVolume(); });
    byId('muteButton').addEventListener('click', () => { audio.muted = !audio.muted; updateVolume(); });
    document.querySelectorAll('.delete-song').forEach(link => link.addEventListener('click', event => {
        if (!window.confirm('¿Eliminar esta canción del catálogo? El archivo de audio se conservará.')) event.preventDefault();
    }));
    document.addEventListener('keydown', event => {
        if (event.target.closest('input, select, textarea, button, a, [contenteditable]')) return;
        if (event.key === '/') { event.preventDefault(); search.focus(); }
        if (event.code === 'Space' && current) { event.preventDefault(); audio.paused ? attemptPlay() : audio.pause(); }
    });
    const editor = document.querySelector('.song-editor');
    if (editor) {
        const focusable = Array.from(editor.querySelectorAll('input:not([type=hidden]), select, button, a'));
        if (focusable[0]) focusable[0].focus();
        editor.addEventListener('keydown', event => {
            if (event.key !== 'Tab' || focusable.length === 0) return;
            const first = focusable[0], last = focusable[focusable.length - 1];
            if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
            else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
        });
    }
})();
