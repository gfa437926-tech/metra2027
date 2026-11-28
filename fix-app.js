// js/fix-app.js - التطبيق الرئيسي لصفحة الأعطال
console.log('🔄 تحميل التطبيق الرئيسي...');

class FixApp {
    constructor() {
        this.formHandler = null;
        this.validation = null;
        this.currentUser = null;
        this.init();
    }

    async init() {
        await this.initializeApp();
        this.setupMobileMenu();
    }

    async initializeApp() {
        try {
            // التحقق من تسجيل الدخول
            this.currentUser = await this.checkLoginStatus();
            if (!this.currentUser) return;

            // تهيئة الواجهة
            this.initializeUserInterface(this.currentUser);
            
            // تحميل القائمة
            this.loadSidebarMenu();
            
            // تهيئة المعالجات
            this.formHandler = new FixFormHandler();
            this.validation = new FixValidation();
            
            // تحميل الإحصائيات
            await this.formHandler.loadFailureStats(this.currentUser.id);
            
            // تعيين التاريخ الحالي
            this.setCurrentDateTime();
            
            // إخفاء شاشة التحميل
            this.hideLoadingScreen();

        } catch (error) {
            console.error('❌ خطأ في تهيئة التطبيق:', error);
            this.showErrorScreen();
        }
    }

    async checkLoginStatus() {
        try {
            const userData = localStorage.getItem('currentUser');
            
            if (!userData) {
                window.location.href = 'index.html';
                return null;
            }
            
            const user = JSON.parse(userData);
            console.log('👤 المستخدم الحالي:', user);
            return user;
            
        } catch (error) {
            console.error('❌ خطأ في التحقق من حالة الدخول:', error);
            localStorage.removeItem('currentUser');
            window.location.href = 'index.html';
            return null;
        }
    }

    initializeUserInterface(user) {
        // تحديث بيانات المستخدم في الواجهة
        document.getElementById('userName').textContent = `${user.first_name} ${user.father_name} ${user.last_name}`;
        document.getElementById('userStation').textContent = user.station || 'غير محدد';
        document.getElementById('userRole').textContent = user.role || 'راصد جوي';
        
        // تحديث بيانات النماذج
        document.getElementById('stationName').textContent = user.station || 'غير محدد';
        document.getElementById('reporterName').textContent = `${user.first_name} ${user.father_name} ${user.last_name}`;
        document.getElementById('manualStationName').textContent = user.station || 'غير محدد';
        document.getElementById('manualReporterName').textContent = `${user.first_name} ${user.father_name} ${user.last_name}`;
    }

    loadSidebarMenu() {
        const sidebarMenu = document.getElementById('sidebarMenu');
        const mobileSidebarMenu = document.getElementById('mobileSidebarMenu');
        
        if (!sidebarMenu || !this.currentUser) return;
        
        const menuItems = [
            { 
                icon: 'fa-solid fa-chart-line', 
                text: 'لوحة التحكم', 
                href: 'main.html' 
            },
            { 
                icon: 'fa-regular fa-clock', 
                text: 'النشرات الساعية', 
                href: 'pages/hourly/hourly_send/hourly_reports.html' 
            },
            { 
                icon: 'fa-regular fa-calendar-days', 
                text: 'النشرات اليومية', 
                href: 'pages/daily/daily_send/daily.html' 
            },
            { 
                icon: 'fa-solid fa-cloud-rain', 
                text: 'النشرات المطرية', 
                href: 'pages/rain/rain_send/rainfall_reports.html' 
            },
            { 
                icon: 'fa-solid fa-wind', 
                text: 'الساعي المناخي', 
                href: 'pages/h_climate/h_climate_send/climate_hourly_reports.html' 
            },
            { 
                icon: 'fa-solid fa-temperature-half', 
                text: 'حرارة التربة', 
                href: 'pages/soil/soil_send/soil-send.html' 
            },
            { 
                icon: 'fa-solid fa-leaf', 
                text: 'النشرات الزراعية', 
                href: 'pages/arg/send-argicultural/agricultural_reports.html' 
            },
            { 
                icon: 'fa-solid fa-microchip', 
                text: 'أعطال أجهزة الرصد', 
                href: 'pages/fix/fix.html',
                active: true
            },
            { 
                icon: 'fa-solid fa-tower-cell', 
                text: 'مشاكل أجهزة الإتصالات', 
                href: 'pages/fix/fix-tel.html' 
            },
            { 
                icon: 'fa-solid fa-right-from-bracket', 
                text: 'تسجيل الخروج', 
                action: 'logout' 
            }
        ];
        
        // بناء القائمة
        const menuHTML = menuItems.map(item => {
            if (item.action === 'logout') {
                return `
                    <li class="nav-item mt-3">
                        <a class="nav-link d-flex align-items-center text-danger logout-btn" href="#">
                            <i class="${item.icon} me-2"></i> ${item.text}
                        </a>
                    </li>
                `;
            }
            
            const isActive = item.active ? 'active' : '';
            return `
                <li class="nav-item mb-2">
                    <a class="nav-link d-flex align-items-center ${isActive}" href="${item.href}">
                        <i class="${item.icon} me-2"></i> ${item.text}
                    </a>
                </li>
            `;
        }).join('');
        
        sidebarMenu.innerHTML = menuHTML;
        if (mobileSidebarMenu) {
            mobileSidebarMenu.innerHTML = menuHTML;
        }
        
        // إضافة معالج حدث تسجيل الخروج
        this.setupLogoutHandlers();
    }

    setupLogoutHandlers() {
        const logoutBtns = document.querySelectorAll('.logout-btn');
        logoutBtns.forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                localStorage.removeItem('currentUser');
                window.location.href = 'index.html';
            });
        });
    }

    setupMobileMenu() {
        const mobileMenuBtn = document.getElementById("mobileMenuBtn");
        const mobileSidebar = document.getElementById("mobileSidebar");
        const mobileSidebarClose = document.getElementById("mobileSidebarClose");
        const mobileOverlay = document.getElementById("mobileOverlay");

        if (!mobileMenuBtn) return;

        mobileMenuBtn.addEventListener("click", function () {
            mobileSidebar.classList.add("active");
            mobileOverlay.classList.add("active");
        });

        mobileSidebarClose.addEventListener("click", function () {
            mobileSidebar.classList.remove("active");
            mobileOverlay.classList.remove("active");
        });

        mobileOverlay.addEventListener("click", function () {
            mobileSidebar.classList.remove("active");
            mobileOverlay.classList.remove("active");
        });
    }

    setCurrentDateTime() {
        const now = new Date();
        now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
        document.getElementById('failureDate').value = now.toISOString().slice(0, 16);
    }

    hideLoadingScreen() {
        document.getElementById("loadingContainer").style.display = "none";
        document.getElementById("mainContainer").style.display = "block";
    }

    showErrorScreen() {
        document.getElementById("errorMessage").style.display = "block";
        document.getElementById("retryButton").addEventListener("click", () => {
            location.reload();
        });
    }
}

// تهيئة التطبيق عند تحميل الصفحة
document.addEventListener('DOMContentLoaded', () => {
    new FixApp();
});