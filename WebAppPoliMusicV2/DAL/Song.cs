using System;
using System.Data;
using System.Data.SqlClient;

namespace WebAppPoliMusicV2.DAL
{
    public class Song
    {
        private readonly string connectionString;

        public Song(string strConnString)
        {
            connectionString = strConnString;
        }

        public DataTable Read()
        {
            const string sql = @"SELECT s.ID_SONG, s.SONG_NAME, s.SONG_PATH, ISNULL(s.PLAYS, 0) AS PLAYS,
                ISNULL((SELECT TOP 1 LTRIM(RTRIM(a.ARTIST_NAME + ' ' + ISNULL(a.ARTIST_LASTNAME, '')))
                    FROM TBL_PLAYER p INNER JOIN TBL_ARTIST a ON a.ID_ARTIST = p.ID_ARTIST
                    WHERE p.ID_SONG = s.ID_SONG ORDER BY a.ID_ARTIST), 'Artista independiente') AS ARTIST,
                ISNULL((SELECT TOP 1 a.TITLE_ALBUM FROM TBL_TRACKLIST t
                    INNER JOIN TBL_ALBUM a ON a.ID_ALBUM = t.ID_ALBUM
                    WHERE t.ID_SONG = s.ID_SONG ORDER BY a.ID_ALBUM), 'Sencillo') AS ALBUM
                FROM TBL_SONG s ORDER BY s.ID_SONG";
            using (SqlConnection connection = new SqlConnection(connectionString))
            using (SqlDataAdapter adapter = new SqlDataAdapter(sql, connection))
            {
                DataTable songs = new DataTable();
                adapter.Fill(songs);
                return songs;
            }
        }

        public Entities.Song Read(int id)
        {
            using (SqlConnection connection = new SqlConnection(connectionString))
            using (SqlCommand command = new SqlCommand(
                "SELECT ID_SONG, SONG_NAME, SONG_PATH, ISNULL(PLAYS, 0) AS PLAYS FROM TBL_SONG WHERE ID_SONG = @ID", connection))
            {
                command.Parameters.Add("@ID", SqlDbType.Int).Value = id;
                connection.Open();
                using (SqlDataReader reader = command.ExecuteReader())
                {
                    if (!reader.Read()) return null;
                    return new Entities.Song
                    {
                        ID = (int)reader["ID_SONG"], Name = (string)reader["SONG_NAME"],
                        Path = (string)reader["SONG_PATH"], Plays = (int)reader["PLAYS"]
                    };
                }
            }
        }

        public int Save(Entities.Song song)
        {
            using (SqlConnection connection = new SqlConnection(connectionString))
            using (SqlCommand command = new SqlCommand(
                "INSERT INTO TBL_SONG (SONG_NAME, SONG_PATH, PLAYS) VALUES (@NAME, @PATH, 0)", connection))
            {
                AddSongParameters(command, song);
                connection.Open();
                return command.ExecuteNonQuery();
            }
        }

        public int Update(Entities.Song song)
        {
            using (SqlConnection connection = new SqlConnection(connectionString))
            using (SqlCommand command = new SqlCommand(
                "UPDATE TBL_SONG SET SONG_NAME = @NAME, SONG_PATH = @PATH WHERE ID_SONG = @ID", connection))
            {
                AddSongParameters(command, song);
                command.Parameters.Add("@ID", SqlDbType.Int).Value = song.ID;
                connection.Open();
                return command.ExecuteNonQuery();
            }
        }

        public int Delete(int id)
        {
            using (SqlConnection connection = new SqlConnection(connectionString))
            {
                connection.Open();
                using (SqlTransaction transaction = connection.BeginTransaction())
                {
                    try
                    {
                        // Remove foreign-key relationships without deleting albums, artists or files.
                        const string sql = @"DELETE FROM TBL_PLAYLIST_SONG WHERE ID_SONG = @ID;
                            DELETE FROM TBL_PLAYER WHERE ID_SONG = @ID;
                            DELETE FROM TBL_TRACKLIST WHERE ID_SONG = @ID;
                            DELETE FROM TBL_SONG WHERE ID_SONG = @ID;";
                        using (SqlCommand command = new SqlCommand(sql, connection, transaction))
                        {
                            command.Parameters.Add("@ID", SqlDbType.Int).Value = id;
                            int affected = command.ExecuteNonQuery();
                            transaction.Commit();
                            return affected;
                        }
                    }
                    catch
                    {
                        transaction.Rollback();
                        throw;
                    }
                }
            }
        }

        public int IncrementPlays(int id)
        {
            using (SqlConnection connection = new SqlConnection(connectionString))
            using (SqlCommand command = new SqlCommand(
                "UPDATE TBL_SONG SET PLAYS = ISNULL(PLAYS, 0) + 1 WHERE ID_SONG = @ID", connection))
            {
                command.Parameters.Add("@ID", SqlDbType.Int).Value = id;
                connection.Open();
                return command.ExecuteNonQuery();
            }
        }

        private static void AddSongParameters(SqlCommand command, Entities.Song song)
        {
            command.Parameters.Add("@NAME", SqlDbType.VarChar, 50).Value = song.Name;
            command.Parameters.Add("@PATH", SqlDbType.VarChar, 255).Value = song.Path;
        }
    }
}
