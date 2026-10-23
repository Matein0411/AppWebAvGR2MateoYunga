(() => {
  "use strict";
  const path = document.getElementById("album-path");
  const preview = document.getElementById("album-preview");
  const choices = [...document.querySelectorAll("[data-cover-path]")];
  const songs = [...document.querySelectorAll("[data-song-choice]")];
  const search = document.getElementById("song-filter");
  const normalize = value => value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase("es");
  let usedFallback = false;
  function showCover() {
    let local = path.value.trim().replaceAll("\\", "/").replace(/^~\//, "");
    if (/^albumimages\//i.test(local)) local = local.replace(/^albumimages\//i, "assets/AlbumImages/");
    const safe = /^assets\/.+\.(jpe?g|png|webp|gif|svg)$/i.test(local) && !/\.\.|[:%?#]/.test(local);
    usedFallback = !safe;
    preview.src = safe ? local : preview.dataset.fallback;
    choices.forEach(button => button.setAttribute("aria-pressed", String(button.dataset.coverPath.toLowerCase() === local.toLowerCase())));
  }
  choices.forEach(button => button.addEventListener("click", () => { path.value = button.dataset.coverPath; showCover(); }));
  path.addEventListener("input", showCover);
  preview.addEventListener("error", () => {
    if (!usedFallback) { usedFallback = true; preview.src = preview.dataset.fallback; }
  });
  function summarize() {
    const count = songs.filter(label => label.querySelector("input").checked).length;
    document.getElementById("selection-summary").textContent = `${count} ${count === 1 ? "canción seleccionada" : "canciones seleccionadas"}`;
  }
  songs.forEach(label => label.querySelector("input").addEventListener("change", summarize));
  search.addEventListener("input", () => {
    const query = normalize(search.value.trim());
    songs.forEach(label => { label.hidden = !normalize(label.textContent).includes(query); });
    document.getElementById("song-filter-empty").hidden = songs.some(label => !label.hidden);
  });
  // Se conserva inicialmente la portada resuelta por ASP, incluidos los respaldos de rutas antiguas.
  summarize();
  choices.forEach(button => button.setAttribute("aria-pressed", String(button.dataset.coverPath.toLowerCase() === path.value.trim().toLowerCase())));
})();
