using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using System.Windows.Navigation;
using System.Diagnostics;

namespace RoundedTB
{
    /// <summary>
    /// Interaction logic for AboutWindow.xaml
    /// </summary>
    public partial class AboutWindow : Wpf.Ui.Controls.FluentWindow
    {
        public AboutWindow()
        {
            InitializeComponent();
            // WPF-UI 4.x:背景由 XAML 的 WindowBackdropType="Mica" 驱动,无需手动 Apply。

            // 按构建通道显示对应横幅(Canary / Dev / Master)
            bannerMst.Visibility = ChannelInfo.Name == "Master" ? Visibility.Visible : Visibility.Hidden;
            bannerDev.Visibility = ChannelInfo.Name == "Dev" ? Visibility.Visible : Visibility.Hidden;
            bannerCan.Visibility = ChannelInfo.Name == "Canary" ? Visibility.Visible : Visibility.Hidden;
            // 按构建通道设置标题栏图标(Icon 需要 ImageSource;x:Static 返回 string 会抛异常)
            aboutTitleBar.Icon = new Wpf.Ui.Controls.ImageIcon { Source = new System.Windows.Media.Imaging.BitmapImage(new Uri(ChannelInfo.IconUri)) };

            // 关闭按钮默认关闭本窗口(WPF-UI 4.x 无 CloseActionOverride;FluentWindow 的
            // 关闭按钮直接 Close,不会退出整个程序,正合本窗口需要)。
        }

        private void okButton_Click(object sender, RoutedEventArgs e)
        {
            Close();
        }
        private void Hyperlink_RequestNavigate(object sender, RequestNavigateEventArgs e)
        {
            Process.Start(e.Uri.ToString());
        }

        private void configButton_Click(object sender, RoutedEventArgs e)
        {
            OpenWithDefaultApp(((MainWindow)Application.Current.MainWindow).configPath);
        }

        private void logButton_Click(object sender, RoutedEventArgs e)
        {
            OpenWithDefaultApp(((MainWindow)Application.Current.MainWindow).logPath);
        }

        /// <summary>用系统默认程序打开指定文件;失败时提示而不是崩溃(Process.Start 在文件不存在/
        /// 无关联程序时会抛异常导致整个程序闪退)。</summary>
        private void OpenWithDefaultApp(string path)
        {
            try
            {
                Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Could not open: " + path + "\n\n" + ex.Message +
                    "\n\n无法打开:" + path + "\n" + ex.Message,
                    "RoundedTB Revived", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }
    }
}
