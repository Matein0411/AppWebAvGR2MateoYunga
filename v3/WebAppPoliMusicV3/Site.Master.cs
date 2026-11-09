using System;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using EntityLayer.PoliMusicV3;
using EntityLayer.PoliMusicV3.Util;

namespace WebAppPoliMusicV3
{
    public partial class SiteMaster : MasterPage
    {
        protected bool IsHome => Page is Song song && song.ShowHome;

        protected override void OnInit(EventArgs e)
        {
            base.OnInit(e);
            if (!Request.IsAuthenticated || !(Session[Constants.USER] is User))
            {
                FormsAuthentication.SignOut();
                Response.Redirect("~/Login");
            }
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            Response.Cache.SetNoStore();
        }
    }
}
