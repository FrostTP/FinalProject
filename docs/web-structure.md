# โครงสร้างเว็บ TimeGuard

เว็บที่ใช้งานจริง: `C:/xampp/htdocs/timeguard_admin/`

- `views/*.html` หน้าจอ HTML มีคำสั่ง PHP สั้น ๆ สำหรับแสดงข้อมูล ลูป และเงื่อนไข ไม่ได้เปิดไฟล์ HTML เหล่านี้โดยตรง
- `controllers/*.php` ตรวจสิทธิ์ รับฟอร์ม ตรวจข้อมูล และเตรียมข้อมูลหน้าจอ
- `controllers/data/*.php` โหลดข้อมูลหน้ารายการและรายละเอียด โดยใช้เงื่อนไขเดิม
- `assets/js/maps.js` แผนที่ Layer มหาวิทยาลัย/แผนกและเครื่องมือ Polygon
- `assets/js/app.js` ปุ่มยืนยันและพิมพ์รายงาน
- `assets/css/app.css`, `reports.css` หน้าตาเว็บเดิม
- `includes/repository.php`, `events.php` ตรรกะบันทึกข้อมูลและอนุมัติ
- `config/` การเชื่อมฐานข้อมูล session และสิทธิ์

URL เดิม เช่น `/timeguard_admin/work_areas/` เป็นจุดเข้า PHP ที่เรียก controller และ HTML view ไม่ต้อง build frontend ไม่ต้องติดตั้งไลบรารีเพิ่ม

แก้หน้าจอที่ views แก้การกดปุ่มที่ assets/js แก้ฝั่งเซิร์ฟเวอร์ที่ controllers/includes การใช้ PHP เพื่อแสดงข้อมูลและตรวจสิทธิ์ยังคงจำเป็น ระบบไม่ได้เปลี่ยนเป็น SPA

ไม่มีการแก้ฐานข้อมูล PHP API มือถือ หรือ Flutter ในการปรับโครงสร้างครั้งนี้

สำรองเว็บก่อนปรับอยู่ที่ `build/web-structure-refactor/backup` ภายในโปรเจกต์ มีข้อมูลตั้งค่าส่วนตัว ไม่ควรเผยแพร่
เทียบ HTML ก่อน/หลัง 43 กรณีแบบอ่านอย่างเดียว ผ่านโดยปรับเฉพาะ whitespace ระหว่างแท็กและ timestamp ของไฟล์ assets ก่อนเทียบ ไม่ได้ทดสอบส่งฟอร์มแก้ข้อมูลจริงหรือความเหมือนเชิงภาพใน browser
