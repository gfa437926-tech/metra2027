// mobile_sidebar.js
document.addEventListener('DOMContentLoaded', function() {
    // عناصر القائمة الجانبية للجوال
    const mobileMenuBtn = document.getElementById('mobileMenuBtn');
    const mobileSidebar = document.getElementById('mobileSidebar');
    const mobileOverlay = document.getElementById('mobileOverlay');
    const mobileSidebarClose = document.getElementById('mobileSidebarClose');
    
    // التحقق من وجود العناصر
    if (!mobileMenuBtn || !mobileSidebar || !mobileOverlay || !mobileSidebarClose) {
        console.warn('⚠️ عناصر القائمة الجانبية للجوال غير موجودة');
        return;
    }
    
    // دالة فتح القائمة
    function openMobileSidebar() {
        console.log('📱 فتح القائمة الجانبية');
        mobileSidebar.classList.add('active');
        mobileOverlay.classList.add('active');
        document.body.style.overflow = 'hidden';
    }
    
    // دالة إغلاق القائمة
    function closeMobileSidebar() {
        console.log('📱 إغلاق القائمة الجانبية');
        mobileSidebar.classList.remove('active');
        mobileOverlay.classList.remove('active');
        document.body.style.overflow = '';
    }
    
    // إضافة مستمعي الأحداث
    mobileMenuBtn.addEventListener('click', openMobileSidebar);
    mobileSidebarClose.addEventListener('click', closeMobileSidebar);
    mobileOverlay.addEventListener('click', closeMobileSidebar);
    
    // إغلاق القائمة عند النقر على أي رابط داخل القائمة
    mobileSidebar.addEventListener('click', function(e) {
        if (e.target.tagName === 'A' || e.target.closest('a')) {
            console.log('📱 تم النقر على رابط في القائمة الجانبية');
            setTimeout(closeMobileSidebar, 300); // تأخير بسيط لرؤية التأثير
        }
    });
    
    // إغلاق القائمة عند الضغط على زر ESC
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && mobileSidebar.classList.contains('active')) {
            closeMobileSidebar();
        }
    });
    
    // جعل الدالة متاحة عالمياً
    window.closeMobileSidebar = closeMobileSidebar;
    window.openMobileSidebar = openMobileSidebar;
    
    console.log('✅ تم تهيئة القائمة الجانبية للجوال بنجاح');
});