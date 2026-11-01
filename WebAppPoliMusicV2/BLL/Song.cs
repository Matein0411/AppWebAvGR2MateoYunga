using System;
using System.Data;
using System.IO;

namespace WebAppPoliMusicV2.BLL
{
    public class Song
    {
        private readonly DAL.Song songs;

        public Song(string strConnString)
        {
            songs = new DAL.Song(strConnString);
        }

        public DataTable Read() { return songs.Read(); }
        public Entities.Song Read(int id) { ValidateID(id); return songs.Read(id); }
        public int Save(Entities.Song song) { Validate(song); return songs.Save(song); }
        public int Update(Entities.Song song) { Validate(song); ValidateID(song.ID); return songs.Update(song); }
        public int Delete(int id) { ValidateID(id); return songs.Delete(id); }
        public int IncrementPlays(int id) { ValidateID(id); return songs.IncrementPlays(id); }

        public static void Validate(Entities.Song song)
        {
            if (song == null) throw new ArgumentException("Introduce los datos de la canción.");
            song.Name = (song.Name ?? string.Empty).Trim();
            if (song.Name.Length == 0 || song.Name.Length > 50)
                throw new ArgumentException("El nombre debe tener entre 1 y 50 caracteres.");
            song.Path = NormalizePath(song.Path);
        }

        public static string NormalizePath(string path)
        {
            path = (path ?? string.Empty).Trim();
            const string prefix = "~/SongFiles/";
            if (!path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) || path.Length > 255)
                throw new ArgumentException("Selecciona un archivo MP3 de la carpeta SongFiles.");
            string file = path.Substring(prefix.Length);
            if (file.Length == 0 || file.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 ||
                file.Contains("..") || file.IndexOfAny(new char[] { '/', '\\', '%', '?', '#', '&', '\'' }) >= 0 ||
                !file.EndsWith(".mp3", StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("La ruta del archivo MP3 no es válida.");
            return prefix + file;
        }

        private static void ValidateID(int id)
        {
            if (id <= 0) throw new ArgumentException("La canción seleccionada no es válida.");
        }
    }
}
