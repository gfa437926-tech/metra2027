// sidebar.js - تحميل القائمة الجانبية ديناميكياً (نسخة معدلة)

// متغير لتتبع حالة التهيئة
let sidebarInitialized = false;

document.addEventListener('DOMContentLoaded', function() {
    console.log('📱 تهيئة القائمة الجانبية...');
    initializeSidebar();
});

function initializeSidebar() {
    if (sidebarInitialized) {
        console.log('⚠️ القائمة الجانبية تم تهيئتها بالفعل');
        return;
    }
    
    // تحميل القائمة الجانبية الرئيسية
    loadMainSidebar();
    
    // تحميل قائمة الجوال
    loadMobileSidebar();
    
    // إعداد مستمعات الأحداث
    setupMobileSidebarEvents();
    
    sidebarInitialized = true;
    console.log('✅ تم تهيئة القائمة الجانبية بنجاح');
}

function loadMainSidebar() {
    console.log('📁 تحميل القائمة الجانبية الرئيسية...');
    
    const mainSidebar = document.querySelector('.sidebar-dashboard');
    if (!mainSidebar) {
        console.error('❌ لم يتم العثور على عنصر القائمة الجانبية الرئيسية');
        return;
    }

    // تنظيف أي محتوى سابق
    mainSidebar.innerHTML = '';
    
    const sidebarHTML = `
        <div class="sidebar-sticky">
            <div class="text-center my-4">
                <h5 class="mt-2 text-white">نظام إدارة البيانات الجوية</h5>
                <p class="text-light mb-0" style="font-size: 0.85rem; opacity: 0.8">
                    الملخص اليومي
                </p>
            </div>

            <ul class="nav flex-column" id="sidebarMenu">
                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../../main.html">
                        <i class="fa-solid fa-chart-line me-2" style="color: #009dff"></i>
                        لوحة التحكم
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/hourly/hourly_send/hourly_reports.html">
                        <i class="fa-regular fa-clock me-2" style="color: #009dff"></i>
                        النشرات الساعية
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center active" href="../../../pages/daily/daily_send/daily.html">
                        <i class="fa-regular fa-calendar-days me-2" style="color: #009dff"></i>
                        الملخص اليومي
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/rain/rain_send/rainfall_reports.html">
                        <i class="fa-solid fa-cloud-rain me-2" style="color: #009dff"></i>
                        النشرات المطرية
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/h_climate/h_climate_send/h_climate_send.html">
                        <i class="fa-solid fa-wind me-2" style="color: #009dff"></i>
                        الساعي المناخي
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/soil/soil_send/soil-send.html">
                        <i class="fa-solid fa-temperature-half me-2" style="color: #009dff"></i>
                        حرارة التربة
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/arg/send-argicultural/agricultural_reports.html">
                        <i class="fa-solid fa-leaf me-2" style="color: #009dff"></i>
                        النشرات الزراعية
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/fix/fix.html">
                        <i class="fa-solid fa-microchip me-2" style="color: #009dff"></i>
                        أعطال أجهزة الرصد
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/fix/fix-tel.html">
                        <i class="fa-solid fa-tower-cell me-2" style="color: #009dff"></i>
                        مشاكل أجهزة الإتصالات
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/fix/it.html">
                        <i class="fa-solid fa-bug me-2" style="color: #009dff"></i>
                        أعطال البرامج (IT)
                    </a>
                </li>

                <li class="nav-item mt-3">
                    <a class="nav-link d-flex align-items-center text-danger" href="../../../index.html">
                        <i class="fa-solid fa-right-from-bracket me-2" style="color: #ff0000"></i>
                        تسجيل الخروج
                    </a>
                </li>
            </ul>
        </div>
    `;

    mainSidebar.innerHTML = sidebarHTML;
    console.log('✅ تم تحميل القائمة الجانبية الرئيسية بنجاح');
}

function loadMobileSidebar() {
    console.log('📱 تحميل قائمة الجوال...');
    
    const mobileSidebar = document.getElementById('mobileSidebar');
    if (!mobileSidebar) {
        console.error('❌ لم يتم العثور على عنصر قائمة الجوال');
        return;
    }

    // تنظيف أي محتوى سابق
    mobileSidebar.innerHTML = '';

    const mobileMenuHTML = `
        <div class="mobile-sidebar-header">
            <h5 class="text-white mb-0">القائمة</h5>
            <button class="mobile-sidebar-close" id="mobileSidebarClose">
                <i class="fas fa-times"></i>
            </button>
        </div>
        <div class="mobile-sidebar-body">
            <ul class="nav flex-column" id="mobileSidebarMenu">
                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../../main.html">
                        <i class="fa-solid fa-chart-line me-2" style="color: #009dff"></i>
                        لوحة التحكم
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/hourly/hourly_send/hourly_reports.html">
                        <i class="fa-regular fa-clock me-2" style="color: #009dff"></i>
                        النشرات الساعية
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center active" href="../../../pages/daily/daily_send/daily.html">
                        <i class="fa-regular fa-calendar-days me-2" style="color: #009dff"></i>
                        الملخص اليومي
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/rain/rain_send/rainfall_reports.html">
                        <i class="fa-solid fa-cloud-rain me-2" style="color: #009dff"></i>
                        النشرات المطرية
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/h_climate/h_climate_send/h_climate_send.html">
                        <i class="fa-solid fa-wind me-2" style="color: #009dff"></i>
                        الساعي المناخي
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/soil/soil_send/soil-send.html">
                        <i class="fa-solid fa-temperature-half me-2" style="color: #009dff"></i>
                        حرارة التربة
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/arg/send-argicultural/agricultural_reports.html">
                        <i class="fa-solid fa-leaf me-2" style="color: #009dff"></i>
                        النشرات الزراعية
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/fix/fix.html">
                        <i class="fa-solid fa-microchip me-2" style="color: #009dff"></i>
                        أعطال أجهزة الرصد
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/fix/fix-tel.html">
                        <i class="fa-solid fa-tower-cell me-2" style="color: #009dff"></i>
                        مشاكل أجهزة الإتصالات
                    </a>
                </li>

                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center" href="../../../pages/fix/it.html">
                        <i class="fa-solid fa-bug me-2" style="color: #009dff"></i>
                        أعطال البرامج (IT)
                    </a>
                </li>

                <li class="nav-item mt-3">
                    <a class="nav-link d-flex align-items-center text-danger" href="../../../index.html">
                        <i class="fa-solid fa-right-from-bracket me-2" style="color: #ff0000"></i>
                        تسجيل الخروج
                    </a>
                </li>
            </ul>
        </div>
    `;

    mobileSidebar.innerHTML = mobileMenuHTML;
    console.log('✅ تم تحميل قائمة الجوال بنجاح');
}

function setupMobileSidebarEvents() {
    console.log('🔧 إعداد مستمعات الأحداث لقائمة الجوال...');
    
    // استخدام setTimeout للتأكد من تحميل DOM
    setTimeout(() => {
        const mobileMenuBtn = document.getElementById('mobileMenuBtn');
        const mobileSidebarClose = document.getElementById('mobileSidebarClose');
        const mobileOverlay = document.getElementById('mobileOverlay');

        // فتح القائمة
        if (mobileMenuBtn) {
            // إزالة أي مستمعات سابقة
            mobileMenuBtn.replaceWith(mobileMenuBtn.cloneNode(true));
            const newMobileMenuBtn = document.getElementById('mobileMenuBtn');
            
            newMobileMenuBtn.addEventListener('click', openMobileSidebar);
            console.log('✅ تم إضافة مستمع لفتح القائمة');
        } else {
            console.error('❌ لم يتم العثور على زر فتح القائمة');
        }

        // إغلاق القائمة
        if (mobileSidebarClose) {
            // إزالة أي مستمعات سابقة
            mobileSidebarClose.replaceWith(mobileSidebarClose.cloneNode(true));
            const newMobileSidebarClose = document.getElementById('mobileSidebarClose');
            
            newMobileSidebarClose.addEventListener('click', closeMobileSidebar);
            console.log('✅ تم إضافة مستمع لإغلاق القائمة');
        }

        if (mobileOverlay) {
            // إزالة أي مستمعات سابقة
            mobileOverlay.replaceWith(mobileOverlay.cloneNode(true));
            const newMobileOverlay = document.getElementById('mobileOverlay');
            
            newMobileOverlay.addEventListener('click', closeMobileSidebar);
            console.log('✅ تم إضافة مستمع للطبقة الخارجية');
        }

        // إغلاق عند النقر على أي رابط في القائمة
        document.addEventListener('click', function(e) {
            const mobileSidebarMenu = document.getElementById('mobileSidebarMenu');
            if (mobileSidebarMenu && e.target.closest('#mobileSidebarMenu .nav-link')) {
                console.log('👆 تم النقر على رابط، إغلاق القائمة...');
                closeMobileSidebar();
            }
        });
    }, 100); // تأخير بسيط لضمان تحميل العناصر
}

function openMobileSidebar() {
    console.log('▶️ فتح القائمة الجانبية للجوال');
    
    const mobileSidebar = document.getElementById('mobileSidebar');
    const mobileOverlay = document.getElementById('mobileOverlay');
    
    if (mobileSidebar && mobileOverlay) {
        mobileSidebar.classList.add('active');
        mobileOverlay.classList.add('active');
        document.body.style.overflow = 'hidden';
        document.body.classList.add('sidebar-open');
        console.log('✅ تم فتح القائمة بنجاح');
    } else {
        console.error('❌ لم يتم العثور على عناصر القائمة');
    }
}

function closeMobileSidebar() {
    console.log('⏏️ إغلاق القائمة الجانبية للجوال');
    
    const mobileSidebar = document.getElementById('mobileSidebar');
    const mobileOverlay = document.getElementById('mobileOverlay');
    
    if (mobileSidebar) {
        mobileSidebar.classList.remove('active');
    }
    if (mobileOverlay) {
        mobileOverlay.classList.remove('active');
    }
    document.body.style.overflow = '';
    document.body.classList.remove('sidebar-open');
    
    console.log('✅ تم إغلاق القائمة بنجاح');
}

// جعل الدوال متاحة للاستخدام في السكريبتات الأخرى
window.openMobileSidebar = openMobileSidebar;
window.closeMobileSidebar = closeMobileSidebar;

console.log('🚀 تم تحميل sidebar.js بنجاح');