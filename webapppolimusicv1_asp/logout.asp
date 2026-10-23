<%@ Language="VBScript" CodePage="65001" %>
<% Option Explicit %>
<!--#include file="includes/common.asp"-->
<%
RequireLogin
RequirePost
Session.Contents.RemoveAll
Session.Abandon
Response.Redirect "login.asp"
%>
