DEMO GIAO DIEN SMART LOCKER
============================
Thu muc nay chi dung de xem truoc giao dien bang du lieu mau. Khong gui gi len may chu.
Truoc khi nop bai, xoa ca thu muc web/demo va tra web/index.html ve trang chuyen huong
toi LoginController.

Cach xem
  NetBeans: bam Run, mo trinh duyet o /<ten du an>/demo/index.html (web/index.html chuyen huong toi do).
  Demo chi gom tep tinh, da thu qua may chu HTTP; chua thu mo truc tiep bang file://.

Tai khoan mau (mat khau 123456)
  admin       Quan tri vien      thay tat ca, sua duoc quyen cua vai tro
  operator1   Nhan vien quan ly  nguoi dung, khu tu, mo tu tu xa, nhat ky
  tech1       Ky thuat vien      chi xem
  auditor1    Kiem toan vien     chi xem, nhat ky, xuat CSV
  student1    Nguoi gui do       CHI thay trang Locker map (chon khu, xem tu, dat cho)
  locked1     tai khoan bi khoa  de thu thong bao loi

Cac trang trong demo (moi trang tuong ung mot JSP that)
  index.html        login.jsp         dang nhap
  dashboard.html    dashboard.jsp     the so lieu, bieu do, bang khu
  map.html          lockerMap.jsp     menu khu + so do tu, goi js/locker-map.js
  users.html        user.jsp          loc, phan trang, khoa, xoa, xuat CSV
  user-form.html    user.jsp (form)   them / sua, kiem tra du lieu nhap
  roles.html        (vai tro)         danh sach vai tro
  role-perm.html    (quyen)           bang tick quyen cho vai tro
  areas.html        lockerBank.jsp    khu tu
  logs.html         audit.jsp         nhat ky dang nhap va thao tac

Phan dung lai khi viet JSP that
  css/app.css, css/locker-map.css, js/app.js, js/locker-map.js
  Bang, form, the so lieu, phan trang dung lai cac class trong app.css (grid, form, filter, pager, tabs, cards).
  Bo cuc menu va thanh tren cung nam trong demo.js, ham renderNav, chuyen sang mot tep nav.jsp.
  Du lieu mau cua so do tu: demo/mock-locker.js, hinh dang JSON giong phan 4.2 trong SmartLocker-frontend/README.md.
