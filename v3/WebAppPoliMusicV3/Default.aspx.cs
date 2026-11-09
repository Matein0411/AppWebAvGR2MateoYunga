using System;
using System.Web.UI;

namespace WebAppPoliMusicV3
{
    public partial class _Default : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            Context.Items[Song.HomeViewKey] = true;
            Server.Transfer("~/Song.aspx", false);
        }
    }
}
