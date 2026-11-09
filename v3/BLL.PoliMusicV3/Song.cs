using System;
using System.Collections.Generic;
using System.IO;
using SongEntity = EntityLayer.PoliMusicV3.Song;

namespace BLL.PoliMusicV3
{
    public class Song
    {
        private readonly DAL.PoliMusicV3.Song songs;

        public Song(string connectionString)
        {
            songs = new DAL.PoliMusicV3.Song(connectionString);
        }

        public List<SongEntity> Read()
        {
            return songs.Read();
        }

        public static string AudioFileName(string path)
        {
            path = (path ?? string.Empty).Trim().Replace('\\', '/');
            int separator = path.LastIndexOf('/');
            string folder = separator < 0 ? string.Empty : path.Substring(0, separator);
            if (!folder.Equals("~/SongFiles", StringComparison.OrdinalIgnoreCase) &&
                !folder.Equals("../SongFiles", StringComparison.OrdinalIgnoreCase) &&
                !folder.Equals("SongFiles", StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }

            string fileName = path.Substring(separator + 1);
            if (fileName.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 ||
                fileName.IndexOfAny(new[] { '%', '#' }) >= 0 ||
                !fileName.EndsWith(".mp3", StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }
            return fileName;
        }
    }
}
