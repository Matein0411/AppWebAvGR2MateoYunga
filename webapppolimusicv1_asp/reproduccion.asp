<%@ Language="VBScript" CodePage="65001" %>
<% Option Explicit %>
<!--#include file="includes/common.asp"-->
<%
' Registro de escucha disponible para ambos roles; nunca modifica nombre, ruta ni asociaciones.
RequireLogin
RequirePost
Response.ContentType = "application/json"
Dim id, connection, command, affected, failed, records
id = PositiveId(Request.Form("id"))
If id = 0 Then
    Response.Status = "400 Bad Request"
    Response.Write "{""ok"":false}"
    Response.End
End If
If TextValue(Session("last_play_id")) = CStr(id) And IsDate(Session("last_play_at")) Then
    If DateDiff("s", Session("last_play_at"), Now) < 30 Then
        Response.Write "{""ok"":true,""counted"":false}"
        Response.End
    End If
End If
Set connection = OpenDatabase()
If connection Is Nothing Then
    Response.Status = "503 Service Unavailable"
    Response.Write "{""ok"":false}"
    Response.End
End If
Set command = DbCommand(connection, "SET NOCOUNT ON; UPDATE dbo.TBL_SONG SET PLAYS = CASE WHEN ISNULL(PLAYS, 0) < 2147483647 THEN ISNULL(PLAYS, 0) + 1 ELSE PLAYS END WHERE ID_SONG = ?; SELECT @@ROWCOUNT AS AFFECTED;")
AddParameter command, "id", adInteger, 4, id
On Error Resume Next
Set records = command.Execute
If Err.Number = 0 Then affected = CLng(records("AFFECTED"))
If Err.Number = 0 Then records.Close
failed = (Err.Number <> 0)
Err.Clear
On Error GoTo 0
connection.Close
Set records = Nothing
Set command = Nothing
Set connection = Nothing
If failed Then
    Response.Status = "503 Service Unavailable"
    Response.Write "{""ok"":false}"
ElseIf affected = 0 Then
    Response.Status = "404 Not Found"
    Response.Write "{""ok"":false}"
Else
    Session("last_play_id") = CStr(id)
    Session("last_play_at") = Now
    Response.Write "{""ok"":true,""counted"":true}"
End If
%>
