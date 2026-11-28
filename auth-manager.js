// js/auth-manager.js - نظام مصادقة مبسط مع المسارات الجديدة
console.log('🔐 تحميل نظام المصادقة المحدث...');

const AuthManager = {
    // التحقق من المصادقة مع المسارات المحدثة
    checkAuth(requiredRole = null) {
        console.log('🔍 التحقق من المصادقة...');
        
        const userData = localStorage.getItem('currentUser');
        
        if (!userData) {
            console.log('❌ لا توجد جلسة نشطة');
            this.redirectToLogin();
            return false;
        }
        
        try {
            const user = JSON.parse(userData);
            
            // التحقق من انتهاء الجلسة (24 ساعة)
            const loginTime = user.login_time;
            if (loginTime && (Date.now() - parseInt(loginTime)) > 24 * 60 * 60 * 1000) {
                console.log('⏰ انتهت مدة الجلسة');
                this.clearSession();
                this.redirectToLogin();
                return false;
            }
            
            if (requiredRole && user.role !== requiredRole) {
                console.log(`❌ صلاحيات غير كافية: ${user.role} مطلوب: ${requiredRole}`);
                this.showAlert('غير مصرح لك بالوصول إلى هذه الصفحة', 'error');
                this.redirectToRolePage(user.role);
                return false;
            }
            
            console.log('✅ المصادقة ناجحة');
            return user;
            
        } catch (error) {
            console.error('❌ خطأ في تحليل بيانات الجلسة:', error);
            this.clearSession();
            this.redirectToLogin();
            return false;
        }
    },
    
    // تحويل المستخدم حسب الصفة مع المسارات الجديدة
    redirectToRolePage(role) {
        const rolePages = {
            'مدير النظام': 'managers/manager-dashboard.html',
            'رئيس محطة': 'managers/station-manager.html',
            'مدير مركز': 'managers/center-manager.html',
            'مبرمج الدعم الفني': 'managers/it-manager.html', // الصفة الجديدة
            'رئيس الاتصالات': 'managers/telecom-manager.html',
            'رئيس الورشات': 'managers/workshop-manager.html',
            'مدقق': 'view-data/rec-main.html',
            'راصد جوي': 'main.html'
        };
        
        const targetPage = rolePages[role] || 'main.html';
        console.log(`🎯 التوجيه حسب الصفة: ${role} → ${targetPage}`);
        
        setTimeout(() => {
            window.location.href = targetPage;
        }, 2000);
    },
    
    redirectToLogin() {
        console.log('🔐 التوجيه إلى صفحة تسجيل الدخول...');
        setTimeout(() => {
            window.location.href = 'index.html';
        }, 1500);
    },
    
    clearSession() {
        localStorage.removeItem('currentUser');
        console.log('🗑️ تم مسح الجلسة');
    },
    
    // تسجيل الخروج
    logout() {
        console.log('🚪 جاري تسجيل الخروج...');
        this.clearSession();
        this.showAlert('تم تسجيل الخروج بنجاح', 'success');
        setTimeout(() => {
            window.location.href = 'index.html';
        }, 1500);
    },
    
    // الحصول على معلومات المستخدم الحالي
    getCurrentUser() {
        try {
            const userData = localStorage.getItem('currentUser');
            return userData ? JSON.parse(userData) : null;
        } catch (error) {
            console.error('❌ خطأ في قراءة بيانات المستخدم:', error);
            return null;
        }
    },
    
    // التحقق من وجود صلاحية معينة
    hasPermission(requiredRole) {
        const user = this.getCurrentUser();
        return user && user.role === requiredRole;
    },
    
    // التحقق من صلاحيات متعددة
    hasAnyPermission(roles) {
        const user = this.getCurrentUser();
        return user && roles.includes(user.role);
    },
    
    // تحديث بيانات المستخدم
    updateUserData(newData) {
        try {
            const currentUser = this.getCurrentUser();
            if (!currentUser) return false;
            
            const updatedUser = { ...currentUser, ...newData };
            localStorage.setItem('currentUser', JSON.stringify(updatedUser));
            console.log('✅ تم تحديث بيانات المستخدم');
            return true;
        } catch (error) {
            console.error('❌ خطأ في تحديث بيانات المستخدم:', error);
            return false;
        }
    },
    
    // عرض التنبيهات
    showAlert(message, type = 'info') {
        const alertDiv = document.createElement('div');
        alertDiv.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
        alertDiv.style.cssText = `
            top: 20px;
            right: 20px;
            z-index: 9999;
            min-width: 300px;
            max-width: 500px;
            direction: rtl;
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
        `;
        
        const icon = type === 'success' ? 'fa-check-circle' : 
                    type === 'error' ? 'fa-exclamation-triangle' : 
                    type === 'warning' ? 'fa-exclamation-circle' : 'fa-info-circle';
        
        alertDiv.innerHTML = `
            <div class="d-flex align-items-center">
                <i class="fas ${icon} me-2"></i>
                <div>${message}</div>
            </div>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;
        
        document.body.appendChild(alertDiv);
        
        setTimeout(() => {
            if (alertDiv.parentNode) {
                alertDiv.remove();
            }
        }, 5000);
    },
    
    // إضافة فئة صلاحيات للعناصر
    applyPermissionClasses() {
        const user = this.getCurrentUser();
        if (!user) return;
        
        // إخفاء العناصر حسب الصفة
        document.querySelectorAll('[data-role]').forEach(element => {
            const allowedRoles = element.getAttribute('data-role').split(',').map(r => r.trim());
            if (!allowedRoles.includes(user.role)) {
                element.style.display = 'none';
            }
        });
        
        // إضافة فئة الصفة للـ body
        document.body.classList.add(`role-${user.role.replace(/\s+/g, '-')}`);
    },
    
    // حماية الروابط
    protectLinks() {
        document.querySelectorAll('a').forEach(link => {
            link.addEventListener('click', (e) => {
                const href = link.getAttribute('href');
                if (href && href.includes('managers/')) {
                    const role = this.extractRoleFromPath(href);
                    if (role && !this.hasPermission(role)) {
                        e.preventDefault();
                        this.showAlert('غير مصرح لك بالوصول إلى هذه الصفحة', 'error');
                    }
                }
            });
        });
    },
    
    extractRoleFromPath(path) {
        const roleMap = {
            'manager-dashboard.html': 'مدير النظام',
            'station-manager.html': 'رئيس محطة',
            'center-manager.html': 'مدير مركز',
            'it-manager.html': 'مبرمج الدعم الفني', // الصفة الجديدة
            'telecom-manager.html': 'رئيس الاتصالات',
            'workshop-manager.html': 'رئيس الورشات'
        };
        
        for (const [file, role] of Object.entries(roleMap)) {
            if (path.includes(file)) {
                return role;
            }
        }
        return null;
    },
    
    // تهيئة النظام
    init() {
        console.log('🔧 تهيئة نظام المصادقة...');
        
        // تطبيق فئات الصلاحيات
        this.applyPermissionClasses();
        
        // حماية الروابط
        this.protectLinks();
        
        // إضافة زر تسجيل الخروج إذا لم يكن موجوداً
        this.addLogoutButton();
        
        console.log('✅ تم تهيئة نظام المصادقة');
    },
    
    addLogoutButton() {
        // البحث عن عنصر لوضع زر تسجيل الخروج
        const header = document.querySelector('header, .navbar, .header');
        if (header && !document.querySelector('.auth-logout-btn')) {
            const logoutBtn = document.createElement('button');
            logoutBtn.className = 'btn btn-outline-danger btn-sm auth-logout-btn';
            logoutBtn.innerHTML = '<i class="fas fa-sign-out-alt me-1"></i> تسجيل الخروج';
            logoutBtn.onclick = (e) => {
                e.preventDefault();
                this.logout();
            };
            
            // وضع الزر في مكان مناسب
            const userInfo = header.querySelector('.user-info, .nav-user');
            if (userInfo) {
                userInfo.parentNode.insertBefore(logoutBtn, userInfo.nextSibling);
            } else {
                header.appendChild(logoutBtn);
            }
        }
    }
};

// تهيئة النظام تلقائياً
document.addEventListener('DOMContentLoaded', () => {
    AuthManager.init();
});

// جعل الدوال متاحة عالمياً
window.AuthManager = AuthManager;
window.logout = function() {
    AuthManager.logout();
};

console.log('✅ تم تحميل نظام المصادقة المحدث بنجاح');