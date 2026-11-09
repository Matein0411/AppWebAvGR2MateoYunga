using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using SongEntity = EntityLayer.PoliMusicV3.Song;

namespace DAL.PoliMusicV3
{
    public class Song
    {
        private const string SelectSongs = @"SELECT s.ID_SONG, s.SONG_NAME, s.SONG_PATH,
            ISNULL((SELECT TOP 1 LTRIM(RTRIM(a.ARTIST_NAME + ' ' + ISNULL(a.ARTIST_LASTNAME, '')))
                FROM dbo.TBL_PLAYER p INNER JOIN dbo.TBL_ARTIST a ON a.ID_ARTIST = p.ID_ARTIST
                WHERE p.ID_SONG = s.ID_SONG ORDER BY a.ID_ARTIST), 'Artista independiente') AS ARTIST,
            ISNULL((SELECT TOP 1 a.TITLE_ALBUM FROM dbo.TBL_TRACKLIST t
                INNER JOIN dbo.TBL_ALBUM a ON a.ID_ALBUM = t.ID_ALBUM
                WHERE t.ID_SONG = s.ID_SONG ORDER BY a.ID_ALBUM), 'Sencillo') AS ALBUM
            FROM dbo.TBL_SONG s";

        private readonly string connectionString;

        public Song(string connectionString)
        {
            this.connectionString = connectionString;
        }

        public List<SongEntity> Read()
        {
            var songs = new List<SongEntity>();
            using (var connection = new SqlConnection(connectionString))
            using (var command = new SqlCommand(SelectSongs + " ORDER BY s.ID_SONG", connection))
            {
                connection.Open();
                using (var reader = command.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        songs.Add(ReadSong(reader));
                    }
                }
            }
            return songs;
        }

        public SongEntity Read(int id)
        {
            using (var connection = new SqlConnection(connectionString))
            using (var command = new SqlCommand(SelectSongs + " WHERE s.ID_SONG = @ID", connection))
            {
                command.Parameters.Add("@ID", SqlDbType.Int).Value = id;
                connection.Open();
                using (var reader = command.ExecuteReader(CommandBehavior.SingleRow))
                {
                    return reader.Read() ? ReadSong(reader) : null;
                }
            }
        }

        public int Save(SongEntity song)
        {
            const string sql = @"INSERT INTO dbo.TBL_SONG (SONG_NAME, SONG_PATH, PLAYS)
                OUTPUT INSERTED.ID_SONG
                VALUES (@NAME, @PATH, 0);";

            using (var connection = new SqlConnection(connectionString))
            using (var command = new SqlCommand(sql, connection))
            {
                AddSongParameters(command, song);
                connection.Open();
                return (int)command.ExecuteScalar();
            }
        }

        public int Update(SongEntity song)
        {
            const string sql = @"UPDATE dbo.TBL_SONG SET SONG_NAME = @NAME, SONG_PATH = @PATH
                WHERE ID_SONG = @ID;";

            using (var connection = new SqlConnection(connectionString))
            using (var command = new SqlCommand(sql, connection))
            {
                AddSongParameters(command, song);
                command.Parameters.Add("@ID", SqlDbType.Int).Value = song.ID;
                connection.Open();
                return command.ExecuteNonQuery();
            }
        }

        public int Delete(int id)
        {
            const string sql = @"DELETE FROM dbo.TBL_PLAYLIST_SONG WHERE ID_SONG = @ID;
                DELETE FROM dbo.TBL_PLAYER WHERE ID_SONG = @ID;
                DELETE FROM dbo.TBL_TRACKLIST WHERE ID_SONG = @ID;
                DELETE FROM dbo.TBL_SONG WHERE ID_SONG = @ID;
                SELECT @@ROWCOUNT;";

            using (var connection = new SqlConnection(connectionString))
            {
                connection.Open();
                using (var transaction = connection.BeginTransaction())
                using (var command = new SqlCommand(sql, connection, transaction))
                {
                    command.Parameters.Add("@ID", SqlDbType.Int).Value = id;
                    int affectedSongs = (int)command.ExecuteScalar();
                    transaction.Commit();
                    return affectedSongs;
                }
            }
        }

        private static SongEntity ReadSong(SqlDataReader reader)
        {
            return new SongEntity
            {
                ID = (int)reader["ID_SONG"],
                Name = (string)reader["SONG_NAME"],
                Path = (string)reader["SONG_PATH"],
                Artist = (string)reader["ARTIST"],
                Album = (string)reader["ALBUM"]
            };
        }

        private static void AddSongParameters(SqlCommand command, SongEntity song)
        {
            if (song == null)
            {
                throw new ArgumentNullException(nameof(song));
            }

            command.Parameters.Add("@NAME", SqlDbType.VarChar).Value = (object)song.Name ?? DBNull.Value;
            command.Parameters.Add("@PATH", SqlDbType.VarChar).Value = (object)song.Path ?? DBNull.Value;
        }
    }
}
