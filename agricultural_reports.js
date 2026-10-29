// agricultural_reports.js - النشرات الزراعية مع الربط الكامل بـ Supabase
console.log('🌱 تحميل نظام النشرات الزراعية مع الربط بقاعدة البيانات...');

// ===== متغيرات النظام =====
let currentUserData = null;
let isConnectedToSupabase = false;

// جعل المتغيرات متاحة عالمياً
window.currentUserData = null;
window.isConnectedToSupabase = false;

// ===== تحويل التاريخ إلى ميلادي =====
function convertToGregorianDate(dateString) {
    if (!dateString) {
        return new Date().toISOString().split('T')[0];
    }
    
    try {
        // إذا كان التاريخ بالفعل بصيغة YYYY-MM-DD
        if (/^\d{4}-\d{2}-\d{2}$/.test(dateString)) {
            return dateString;
        }
        
        // إذا كان التاريخ بصيغة مختلفة، نحاول تحويله
        const date = new Date(dateString);
        if (isNaN(date.getTime())) {
            // إذا فشل التحليل، نعيد التاريخ الحالي
            return new Date().toISOString().split('T')[0];
        }
        
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        
        return `${year}-${month}-${day}`;
        
    } catch (error) {
        console.error('❌ خطأ في تحويل التاريخ الميلادي:', error);
        return new Date().toISOString().split('T')[0];
    }
}

// ===== التحقق من حالة المصادقة =====
async function checkAuthStatus() {
    try {
        console.log('🔐 التحقق من حالة المصادقة...');
        
        if (!window.supabaseClient) {
            console.warn('⚠️ عميل Supabase غير متاح');
            return null;
        }
        
        const { data: { user }, error } = await supabaseClient.auth.getUser();
        
        if (error) {
            console.warn('⚠️ تحذير في التحقق من المصادقة:', error.message);
            return null;
        }
        
        if (user) {
            console.log('✅ مستخدم مصادق عليه:', user.email);
            return user;
        } else {
            console.log('ℹ️ لا يوجد مستخدم مصادق عليه');
            return null;
        }
        
    } catch (error) {
        console.error('❌ خطأ في التحقق من المصادقة:', error);
        return null;
    }
}

// ===== إنشاء مستخدم مؤقت =====
function createTemporaryUser() {
    // توليد UUID صالح للمستخدم المؤقت
    const uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
    
    return {
        id: uuid,
        email: 'temp@example.com',
        station: 'المحطة الافتراضية',
        role: 'راصد جوي',
        name: 'مستخدم مؤقت',
        first_name: 'مستخدم',
        last_name: 'مؤقت'
    };
}

// ===== تهيئة النظام عند تحميل الصفحة =====
document.addEventListener('DOMContentLoaded', async function() {
    console.log('🚀 بدء تهيئة نظام النشرات الزراعية...');
    
    // 1. تهيئة القائمة الجانبية للجوال
    initMobileMenu();
    
    // 2. تعيين التواريخ (الميلادي)
    initGregorianDates();
    
    // 3. تحميل بيانات المستخدم
    await loadUserData();
    
    // 4. التحقق من اتصال Supabase
    isConnectedToSupabase = await checkSupabaseConnection();
    
    // 5. تهيئة المكونات
    initFieldValidation();
    initSignButtons();
    initActionButtons();
    setupAutoFormatting();
    
    // 6. تحميل المسودة المحفوظة
    loadDraft();
    
    // 7. تحديث جميع العروض
    updateAllDisplays();
    
    // 8. إضافة أزرار العرض حسب الصلاحيات
    setupViewButtonsByRole();
    
    // 9. إضافة معالجات تفاصيل التقارير
    setupReportDetailsView();
    
    // 10. إضافة زر اختبار الإرسال
    addTestSubmitButton();
    
    // 11. جعل المتغيرات متاحة للاختبار
    window.currentUserData = currentUserData;
    window.isConnectedToSupabase = isConnectedToSupabase;
    
    console.log('✅ تم تهيئة نظام النشرات الزراعية بنجاح');
    console.log('👤 المستخدم:', currentUserData);
    console.log('🔗 اتصال Supabase:', isConnectedToSupabase);
});

// ===== وظائف تهيئة النظام =====

// تهيئة القائمة الجانبية للجوال
function initMobileMenu() {
    const mobileMenuBtn = document.getElementById('mobileMenuBtn');
    const mobileSidebar = document.getElementById('mobileSidebar');
    const mobileSidebarClose = document.getElementById('mobileSidebarClose');
    const mobileOverlay = document.getElementById('mobileOverlay');
    
    if (!mobileMenuBtn) return;
    
    mobileMenuBtn.addEventListener('click', function() {
        mobileSidebar.classList.add('active');
        mobileOverlay.classList.add('active');
        document.body.style.overflow = 'hidden';
    });
    
    function closeMobileSidebar() {
        mobileSidebar.classList.remove('active');
        mobileOverlay.classList.remove('active');
        document.body.style.overflow = '';
    }
    
    mobileSidebarClose.addEventListener('click', closeMobileSidebar);
    mobileOverlay.addEventListener('click', closeMobileSidebar);
    
    const mobileNavLinks = document.querySelectorAll('#mobileSidebarMenu .nav-link');
    mobileNavLinks.forEach(link => {
        link.addEventListener('click', closeMobileSidebar);
    });
}

// تهيئة التواريخ (الميلادي)
function initGregorianDates() {
    // تاريخ اليوم الميلادي
    const now = new Date();
    const gregorianDate = now.toISOString().split('T')[0]; // YYYY-MM-DD
    
    const currentDateField = document.getElementById('currentDate');
    if (currentDateField) {
        // عرض التاريخ الميلادي والهجري معاً
        const hijriDate = now.toLocaleDateString('ar-EG', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
        
        currentDateField.value = `التاريخ الميلادي: ${gregorianDate} | الهجري: ${hijriDate}`;
        currentDateField.setAttribute('title', 'التاريخ الميلادي للتخزين في قاعدة البيانات');
    }
    
    // تاريخ التقرير (اليوم الميلادي)
    const reportDate = document.getElementById('reportDate');
    if (reportDate) {
        // استخدام التاريخ الميلادي
        reportDate.value = gregorianDate;
        
        // تحديد أول وأخر يوم (سنة سابقة إلى اليوم)
        const today = new Date();
        const lastYear = new Date();
        lastYear.setFullYear(today.getFullYear() - 1);
        
        reportDate.setAttribute('min', lastYear.toISOString().split('T')[0]);
        reportDate.setAttribute('max', today.toISOString().split('T')[0]);
        reportDate.setAttribute('title', 'اختر التاريخ الميلادي للتقرير');
    }
}

// تحميل بيانات المستخدم
async function loadUserData() {
    try {
        console.log('👤 تحميل بيانات المستخدم...');
        
        // التحقق من حالة المصادقة
        const user = await checkAuthStatus();
        
        if (user) {
            console.log('✅ تم العثور على مستخدم مصادق عليه:', user.email);
            
            // جلب بيانات الملف الشخصي من Supabase
            let profileData = null;
            
            try {
                const { data: profile, error } = await supabaseClient
                    .from('user_profiles')
                    .select('*')
                    .eq('user_id', user.id)
                    .single();
                
                if (!error && profile) {
                    profileData = profile;
                    console.log('✅ تم تحميل الملف الشخصي من Supabase');
                }
            } catch (profileError) {
                console.warn('⚠️ خطأ في جلب الملف الشخصي:', profileError.message);
            }
            
            if (profileData) {
                currentUserData = {
                    id: user.id,
                    email: user.email,
                    name: user.email,
                    ...profileData
                };
            } else {
                currentUserData = {
                    id: user.id,
                    email: user.email,
                    name: user.email,
                    station: 'المحطة الرئيسية',
                    role: 'راصد جوي',
                    first_name: user.email.split('@')[0] || 'مستخدم',
                    last_name: 'Supabase'
                };
                
                console.log('⚠️ استخدام بيانات افتراضية للمستخدم');
            }
            
        } else {
            console.log('⚠️ لا يوجد مستخدم مصادق عليه، استخدام البيانات المحلية');
            
            // استخدام بيانات محلية كاحتياطي
            const savedUser = localStorage.getItem('currentUser');
            if (savedUser) {
                currentUserData = JSON.parse(savedUser);
                console.log('✅ تم تحميل المستخدم من localStorage');
            } else {
                currentUserData = createTemporaryUser();
                console.log('✅ تم إنشاء مستخدم مؤقت');
            }
        }
        
        // حفظ البيانات محلياً للاستخدام اللاحق
        localStorage.setItem('currentUser', JSON.stringify(currentUserData));
        
        // تحديث المتغيرات العالمية
        window.currentUserData = currentUserData;
        
        // تحديث العرض
        updateUserDisplay();
        updateUserStatus();
        updateGlobalStatus();
        
        console.log('👤 بيانات المستخدم النهائية:', currentUserData);
        
        return currentUserData;
        
    } catch (error) {
        console.error('❌ خطأ في تحميل بيانات المستخدم:', error);
        
        // إنشاء مستخدم افتراضي في حالة الخطأ
        currentUserData = createTemporaryUser();
        window.currentUserData = currentUserData;
        
        // حفظ البيانات محلياً
        localStorage.setItem('currentUser', JSON.stringify(currentUserData));
        
        return currentUserData;
    }
}

// تحديث عرض بيانات المستخدم
function updateUserDisplay() {
    const userName = document.getElementById('userName');
    const userStation = document.getElementById('userStation');
    const userRole = document.getElementById('userRole');
    
    if (!currentUserData) {
        userName.textContent = 'زائر';
        userStation.textContent = 'غير محدد';
        userRole.textContent = 'مستخدم';
        return;
    }
    
    const fullName = `${currentUserData.first_name || ''} ${currentUserData.last_name || ''}`.trim();
    
    userName.textContent = fullName || currentUserData.name || currentUserData.email || 'مستخدم';
    userStation.textContent = currentUserData.station || currentUserData.station_name || currentUserData.user_station || 'غير محدد';
    userRole.textContent = currentUserData.role || currentUserData.job || 'راصد جوي';
}

// التحقق من اتصال Supabase
async function checkSupabaseConnection() {
    try {
        console.log('🔗 التحقق من اتصال Supabase...');
        
        if (!window.supabaseClient) {
            console.warn('⚠️ عميل Supabase غير متوفر');
            window.isConnectedToSupabase = false;
            updateGlobalStatus();
            return false;
        }
        
        // اختبار الاتصال بمحاولة جلب عدد صغير من السجلات
        const { data, error } = await supabaseClient
            .from('agricultural_reports')
            .select('id')
            .limit(1);
        
        if (error) {
            // إذا كان الخطأ هو أن الجدول غير موجود، فهذا يعني أن الاتصال يعمل
            if (error.message.includes('does not exist') || error.code === 'PGRST116') {
                console.log('✅ اتصال Supabase نشط (الجدول غير موجود بعد)');
                window.isConnectedToSupabase = true;
                updateGlobalStatus();
                return true;
            }
            
            // إذا كان الخطأ متعلقاً بعمود date_format، تجاهله
            if (error.message.includes('date_format')) {
                console.log('✅ اتصال Supabase نشط (مشكلة في عمود date_format فقط)');
                window.isConnectedToSupabase = true;
                updateGlobalStatus();
                return true;
            }
            
            console.warn('⚠️ اتصال Supabase به مشاكل:', error.message);
            window.isConnectedToSupabase = false;
            updateGlobalStatus();
            return false;
        }
        
        console.log('✅ اتصال Supabase نشط');
        window.isConnectedToSupabase = true;
        updateGlobalStatus();
        return true;
        
    } catch (error) {
        console.error('❌ خطأ في التحقق من اتصال Supabase:', error);
        window.isConnectedToSupabase = false;
        updateGlobalStatus();
        return false;
    }
}

// تحديث حالة النظام في النطاق العام
function updateGlobalStatus() {
    window.currentUserData = currentUserData;
    window.isConnectedToSupabase = isConnectedToSupabase;
    
    console.log('🔄 تحديث حالة النظام:');
    console.log('👤 المستخدم:', currentUserData ? 'موجود' : 'غير موجود');
    console.log('🔗 اتصال Supabase:', isConnectedToSupabase);
    
    // تحديث واجهة المستخدم
    updateConnectionDisplay();
}

// تحديث عرض حالة الاتصال
function updateConnectionDisplay() {
    const connectionElement = document.getElementById('connectionStatus');
    if (!connectionElement) return;
    
    if (isConnectedToSupabase) {
        connectionElement.innerHTML = '<i class="fas fa-check-circle text-success me-2"></i>متصل بقاعدة البيانات';
        connectionElement.className = 'alert alert-success text-center';
    } else {
        connectionElement.innerHTML = '<i class="fas fa-exclamation-triangle text-warning me-2"></i>الاتصال محدود - سيتم الحفظ محلياً';
        connectionElement.className = 'alert alert-warning text-center';
    }
}

// تحديث حالة المستخدم في الواجهة
function updateUserStatus() {
    const userStatusElement = document.getElementById('userStatusText');
    const userEmailElement = document.getElementById('userEmailText');
    const userStationElement = document.getElementById('userStationText');
    
    if (userStatusElement) {
        if (currentUserData && currentUserData.id && !currentUserData.id.startsWith('temp-')) {
            userStatusElement.textContent = 'مسجل في النظام';
            userStatusElement.className = 'text-success';
        } else if (currentUserData) {
            userStatusElement.textContent = 'نسخة تجريبية (محلي)';
            userStatusElement.className = 'text-warning';
        } else {
            userStatusElement.textContent = 'غير مسجل';
            userStatusElement.className = 'text-danger';
        }
    }
    
    if (userEmailElement && currentUserData) {
        userEmailElement.textContent = currentUserData.email || 'غير محدد';
    }
    
    if (userStationElement && currentUserData) {
        userStationElement.textContent = currentUserData.station || currentUserData.user_station || 'غير محدد';
    }
}

// تحديث عرض حالة النظام
function updateSystemDisplay() {
    // تحديث حالة النظام
    const dbStatusText = document.getElementById('dbStatusText');
    const systemStatusAlert = document.getElementById('systemStatusAlert');
    const lastUpdateTime = document.getElementById('lastUpdateTime');
    const localStorageStatus = document.getElementById('localStorageStatus');
    
    if (dbStatusText) {
        if (isConnectedToSupabase) {
            dbStatusText.textContent = '✓ متصل';
            dbStatusText.className = 'text-success';
        } else {
            dbStatusText.textContent = '✗ غير متصل (سيتم الحفظ محلياً)';
            dbStatusText.className = 'text-warning';
        }
    }
    
    if (systemStatusAlert) {
        systemStatusAlert.className = isConnectedToSupabase ? 
            'alert alert-success' : 'alert alert-warning';
    }
    
    if (lastUpdateTime) {
        lastUpdateTime.textContent = new Date().toLocaleTimeString('ar-EG');
    }
    
    if (localStorageStatus) {
        try {
            localStorage.setItem('test_storage', 'test');
            localStorage.removeItem('test_storage');
            localStorageStatus.textContent = '✓ جاهز';
            localStorageStatus.className = 'text-success';
        } catch (e) {
            localStorageStatus.textContent = '✗ غير متاح';
            localStorageStatus.className = 'text-danger';
        }
    }
}

// تحديث كل الدالات
function updateAllDisplays() {
    updateUserDisplay();
    updateUserStatus();
    updateGlobalStatus();
    updateSystemDisplay();
    updateConnectionDisplay();
}

// ===== نظام التنسيق التلقائي =====

function setupAutoFormatting() {
    addFormattingStyles();
    setupTemperatureAutoFormatting();
    setupHumidityAutoFormatting();
    setupDecimalAutoFormatting();
    setupIntegerAutoFormatting();
}

function addFormattingStyles() {
    if (document.getElementById('agricultural-auto-format-styles')) return;
    
    const style = document.createElement('style');
    style.id = 'agricultural-auto-format-styles';
    style.textContent = `
        .auto-formatted {
            border-left: 4px solid #ffc107 !important;
            background-color: #fffaf0 !important;
        }
        
        .needs-review {
            border-color: #ffc107 !important;
            box-shadow: 0 0 0 0.2rem rgba(255, 193, 7, 0.25) !important;
            background-color: #fffaf0 !important;
            animation: pulse-warning 2s infinite;
        }
        
        .format-error {
            border-color: #dc3545 !important;
            box-shadow: 0 0 0 0.2rem rgba(220, 53, 69, 0.25) !important;
            background-color: #fff5f5 !important;
            animation: pulse-error 2s infinite;
        }
        
        @keyframes pulse-warning {
            0% { background-color: #fffaf0; }
            50% { background-color: #fff3cd; }
            100% { background-color: #fffaf0; }
        }
        
        @keyframes pulse-error {
            0% { background-color: #fff5f5; }
            50% { background-color: #ffe6e6; }
            100% { background-color: #fff5f5; }
        }
    `;
    document.head.appendChild(style);
}

function setupTemperatureAutoFormatting() {
    const temperatureFields = [
        'avgAirTemp', 'maxAirTemp', 'minAirTemp', 'minTemp2m', 
        'maxSoilSurfaceTemp', 'minSoilSurfaceTemp', 'avgSoilTemp5cm',
        'avgSoilTemp10cm', 'avgSoilTemp20cm', 'avgSoilTemp50cm',
        'fieldSoilTemp5cm', 'fieldSoilTemp10cm'
    ];
    
    temperatureFields.forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field) {
            field.addEventListener('blur', function() {
                enhancedAutoFormatTemperature(this);
            });
            
            field.addEventListener('input', function() {
                clearAutoFormatting(this);
            });
        }
    });
}

function setupHumidityAutoFormatting() {
    const humidityFields = ['avgHumidity', 'minHumidity'];
    
    humidityFields.forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field) {
            field.addEventListener('blur', function() {
                enhancedAutoFormatHumidity(this);
            });
            
            field.addEventListener('input', function() {
                clearAutoFormatting(this);
                this.value = this.value.replace(/[^0-9]/g, '');
            });
        }
    });
}

function setupDecimalAutoFormatting() {
    const decimalFields = [
        'avgEsE', 'minEsE', 'sunshineHours', 'classAEvaporation',
        'avgWindSpeed2m', 'logEvaporation'
    ];
    
    decimalFields.forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field) {
            field.addEventListener('blur', function() {
                enhancedAutoFormatDecimal(this, 4);
            });
            
            field.addEventListener('input', function() {
                clearAutoFormatting(this);
            });
        }
    });
}

function setupIntegerAutoFormatting() {
    const integerFields = [
        'totalCloudCover', 'lowCloudCover', 'maxWindSpeed'
    ];
    
    integerFields.forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field) {
            field.addEventListener('blur', function() {
                enhancedAutoFormatInteger(this, 2);
            });
            
            field.addEventListener('input', function() {
                clearAutoFormatting(this);
                this.value = this.value.replace(/[^0-9]/g, '');
            });
        }
    });
    
    const precipitationField = document.getElementById('precipitation');
    if (precipitationField) {
        precipitationField.addEventListener('blur', function() {
            enhancedAutoFormatDecimal(this, 5);
        });
        
        precipitationField.addEventListener('input', function() {
            clearAutoFormatting(this);
        });
    }
}

// التنسيق التلقائي لدرجات الحرارة
function enhancedAutoFormatTemperature(field) {
    let value = field.value.trim();
    if (!value) {
        field.classList.remove('auto-formatted', 'needs-review', 'format-error');
        return;
    }
    
    const originalValue = value;
    let wasFormatted = false;
    let hasFormatError = false;
    let formatMessage = '';
    
    value = value.replace(/[^0-9.\-+]/g, '');
    
    if (!value.startsWith('+') && !value.startsWith('-')) {
        value = '+' + value;
        wasFormatted = true;
        hasFormatError = true;
        formatMessage = 'تم إضافة إشارة + تلقائياً';
    }
    
    if (!value.includes('.')) {
        if (value.length > 0) {
            let numPart = value.replace(/[^0-9]/g, '');
            if (numPart.length === 1) {
                numPart = '0' + numPart;
                wasFormatted = true;
                hasFormatError = true;
                formatMessage = 'تم تنسيق درجة الحرارة إلى ±dd.d';
            }
            value = (value.startsWith('-') ? '-' : '+') + numPart + '.0';
        }
    } else {
        const parts = value.split('.');
        let numPart = parts[0].replace(/[^0-9]/g, '');
        
        if (numPart.length === 1) {
            numPart = '0' + numPart;
            wasFormatted = true;
            hasFormatError = true;
            formatMessage = 'تم تنسيق درجة الحرارة إلى ±dd.d';
        }
        
        if (parts.length === 2 && parts[1].length === 0) {
            value = (value.startsWith('-') ? '-' : '+') + numPart + '.0';
            wasFormatted = true;
            hasFormatError = true;
            formatMessage = 'تم إضافة صفر بعد الفاصلة العشرية';
        } else if (parts.length === 2 && parts[1].length > 1) {
            value = (value.startsWith('-') ? '-' : '+') + numPart + '.' + parts[1].charAt(0);
            wasFormatted = true;
            hasFormatError = true;
            formatMessage = 'تم تقليل الأرقام بعد الفاصلة إلى رقم واحد';
        } else {
            value = (value.startsWith('-') ? '-' : '+') + numPart + '.' + (parts[1] || '0');
        }
    }
    
    const numericValue = parseFloat(value);
    if (numericValue < -20.0 || numericValue > 60.0) {
        hasFormatError = true;
        formatMessage = 'القيمة خارج النطاق المسموح (-20.0 إلى 60.0)';
    }
    
    if (value !== originalValue) {
        field.value = value;
        wasFormatted = true;
    }
    
    applyFormattingStyles(field, wasFormatted, hasFormatError, formatMessage);
    validateField(field.id, getValidationRules()[field.id]);
}

// التنسيق التلقائي للرطوبة
function enhancedAutoFormatHumidity(field) {
    let value = field.value.trim();
    if (!value) {
        field.classList.remove('auto-formatted', 'needs-review', 'format-error');
        return;
    }
    
    const originalValue = value;
    let wasFormatted = false;
    let hasFormatError = false;
    let formatMessage = '';
    
    value = value.replace(/[^0-9]/g, '');
    
    if (value.length === 1) {
        value = '00' + value;
        wasFormatted = true;
        hasFormatError = true;
        formatMessage = 'تم إضافة أصفار لتنسيق الرطوبة النسبية (3 أرقام)';
    } else if (value.length === 2) {
        value = '0' + value;
        wasFormatted = true;
        hasFormatError = true;
        formatMessage = 'تم إضافة صفر لتنسيق الرطوبة النسبية (3 أرقام)';
    }
    
    const numericValue = parseInt(value);
    if (numericValue > 100) {
        value = '100';
        wasFormatted = true;
        hasFormatError = true;
        formatMessage = 'تم تعديل القيمة إلى الحد الأقصى للرطوبة النسبية (100)';
    }
    
    if (value !== originalValue) {
        field.value = value;
        wasFormatted = true;
    }
    
    applyFormattingStyles(field, wasFormatted, hasFormatError, formatMessage);
    validateField(field.id, getValidationRules()[field.id]);
}

// التنسيق التلقائي للقيم العشرية
function enhancedAutoFormatDecimal(field, maxLength) {
    let value = field.value.trim();
    if (!value) {
        field.classList.remove('auto-formatted', 'needs-review', 'format-error');
        return;
    }
    
    const originalValue = value;
    let wasFormatted = false;
    let hasFormatError = false;
    let formatMessage = '';
    
    value = value.replace(/[^0-9.]/g, '');
    
    if (!value.includes('.')) {
        if (value.length > 0) {
            let numPart = value;
            if (maxLength === 4 && numPart.length === 1) {
                numPart = '0' + numPart;
                wasFormatted = true;
                hasFormatError = true;
                formatMessage = 'تم تنسيق القيمة إلى dd.d';
            } else if (maxLength === 5 && numPart.length === 1) {
                numPart = '00' + numPart;
                wasFormatted = true;
                hasFormatError = true;
                formatMessage = 'تم تنسيق القيمة إلى ddd.d';
            } else if (maxLength === 5 && numPart.length === 2) {
                numPart = '0' + numPart;
                wasFormatted = true;
                hasFormatError = true;
                formatMessage = 'تم تنسيق القيمة إلى ddd.d';
            }
            value = numPart + '.0';
        }
    } else {
        const parts = value.split('.');
        let numPart = parts[0];
        
        if (maxLength === 4 && numPart.length === 1) {
            numPart = '0' + numPart;
            wasFormatted = true;
            hasFormatError = true;
            formatMessage = 'تم تنسيق القيمة إلى dd.d';
        } else if (maxLength === 5 && numPart.length === 1) {
            numPart = '00' + numPart;
            wasFormatted = true;
            hasFormatError = true;
            formatMessage = 'تم تنسيق القيمة إلى ddd.d';
        } else if (maxLength === 5 && numPart.length === 2) {
            numPart = '0' + numPart;
            wasFormatted = true;
            hasFormatError = true;
            formatMessage = 'تم تنسيق القيمة إلى ddd.d';
        }
        
        if (parts.length === 2 && parts[1].length === 0) {
            value = numPart + '.0';
            wasFormatted = true;
            hasFormatError = true;
            formatMessage = 'تم إضافة صفر بعد الفاصلة العشرية';
        } else if (parts.length === 2 && parts[1].length > 1) {
            value = numPart + '.' + parts[1].charAt(0);
            wasFormatted = true;
            hasFormatError = true;
            formatMessage = 'تم تقليل الأرقام بعد الفاصلة إلى رقم واحد';
        } else {
            value = numPart + '.' + (parts[1] || '0');
        }
    }
    
    if (value !== originalValue) {
        field.value = value;
        wasFormatted = true;
    }
    
    applyFormattingStyles(field, wasFormatted, hasFormatError, formatMessage);
    validateField(field.id, getValidationRules()[field.id]);
}

// التنسيق التلقائي للقيم الصحيحة
function enhancedAutoFormatInteger(field, requiredLength) {
    let value = field.value.trim();
    if (!value) {
        field.classList.remove('auto-formatted', 'needs-review', 'format-error');
        return;
    }
    
    const originalValue = value;
    let wasFormatted = false;
    let hasFormatError = false;
    let formatMessage = '';
    
    value = value.replace(/[^0-9]/g, '');
    
    if (requiredLength === 2 && value.length === 1) {
        value = '0' + value;
        wasFormatted = true;
        hasFormatError = true;
        formatMessage = 'تم إضافة صفر لتنسيق القيمة (رقمان)';
    } else if (requiredLength === 3 && value.length === 1) {
        value = '00' + value;
        wasFormatted = true;
        hasFormatError = true;
        formatMessage = 'تم إضافة أصفار لتنسيق القيمة (3 أرقام)';
    } else if (requiredLength === 3 && value.length === 2) {
        value = '0' + value;
        wasFormatted = true;
        hasFormatError = true;
        formatMessage = 'تم إضافة صفر لتنسيق القيمة (3 أرقام)';
    }
    
    if (value !== originalValue) {
        field.value = value;
        wasFormatted = true;
    }
    
    applyFormattingStyles(field, wasFormatted, hasFormatError, formatMessage);
    validateField(field.id, getValidationRules()[field.id]);
}

// تطبيق أنماط التنسيق
function applyFormattingStyles(field, wasFormatted, hasFormatError, message) {
    if (wasFormatted) {
        if (hasFormatError) {
            field.classList.add('auto-formatted', 'format-error');
            showFieldFormatNotification(field, message || 'التنسيق الذي تم إدخاله خاطئ! تم التنسيق تلقائياً.', 'error');
        } else {
            field.classList.add('auto-formatted', 'needs-review');
            showFieldFormatNotification(field, 'تم تنسيق القيمة تلقائياً. يرجى المراجعة.', 'warning');
        }
        
        setTimeout(() => {
            if (document.activeElement !== field) {
                field.classList.remove('needs-review', 'format-error');
            }
        }, 5000);
        
        const clearFormatting = function() {
            field.classList.remove('auto-formatted', 'needs-review', 'format-error');
            field.removeEventListener('focus', clearFormatting);
        };
        field.addEventListener('focus', clearFormatting);
    }
}

// مسح أنماط التنسيق
function clearAutoFormatting(field) {
    field.classList.remove('auto-formatted', 'needs-review', 'format-error');
    
    const existingNotification = field.parentNode.querySelector('.field-format-notification');
    if (existingNotification) {
        existingNotification.remove();
    }
}

// إظهار إشعار تنسيق الحقل
function showFieldFormatNotification(field, message, type = 'warning') {
    const existingNotification = field.parentNode.querySelector('.field-format-notification');
    if (existingNotification) {
        existingNotification.remove();
    }
    
    const alertClass = type === 'error' ? 'alert-danger' : 'alert-warning';
    const icon = type === 'error' ? 'fa-exclamation-circle' : 'fa-exclamation-triangle';
    
    const notification = document.createElement('div');
    notification.className = 'field-format-notification';
    notification.innerHTML = `
        <div class="alert ${alertClass} alert-dismissible fade show" role="alert">
            <i class="fas ${icon} me-2"></i>
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
    `;
    
    field.parentNode.appendChild(notification);
    
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, 4000);
}

// ===== نظام التحقق من الصحة =====

function getValidationRules() {
    return {
        avgAirTemp: { pattern: /^[+-]?\d{1,2}\.\d$/, min: -20.0, max: 60.0, type: 'temperature' },
        maxAirTemp: { pattern: /^[+-]?\d{1,2}\.\d$/, min: -20.0, max: 60.0, type: 'temperature' },
        minAirTemp: { pattern: /^[+-]?\d{1,2}\.\d$/, min: -20.0, max: 60.0, type: 'temperature' },
        minTemp2m: { pattern: /^[+-]?\d{1,2}\.\d$/, min: -20.0, max: 60.0, type: 'temperature' },
        maxSoilSurfaceTemp: { pattern: /^[+-]?\d{1,2}\.\d$/, min: -20.0, max: 60.0, type: 'temperature' },
        minSoilSurfaceTemp: { pattern: /^[+-]?\d{1,2}\.\d$/, min: -20.0, max: 60.0, type: 'temperature' },
        avgSoilTemp5cm: { pattern: /^[+-]?\d{1,2}\.\d$/, min: -20.0, max: 60.0, type: 'temperature' },
        avgSoilTemp10cm: { pattern: /^[+-]?\d{1,2}\.\d$/, min: -20.0, max: 60.0, type: 'temperature' },
        avgSoilTemp20cm: { pattern: /^[+-]?\d{1,2}\.\d$/, min: -20.0, max: 60.0, type: 'temperature' },
        avgSoilTemp50cm: { pattern: /^[+-]?\d{1,2}\.\d$/, min: -20.0, max: 60.0, type: 'temperature' },
        fieldSoilTemp5cm: { pattern: /^[+-]?\d{1,2}\.\d$/, min: -20.0, max: 60.0, type: 'temperature' },
        fieldSoilTemp10cm: { pattern: /^[+-]?\d{1,2}\.\d$/, min: -20.0, max: 60.0, type: 'temperature' },
        
        avgHumidity: { pattern: /^\d{3}$/, min: 0, max: 100, type: 'humidity' },
        minHumidity: { pattern: /^\d{3}$/, min: 0, max: 100, type: 'humidity' },
        
        avgEsE: { pattern: /^\d{1,2}\.\d$/, type: 'decimal' },
        minEsE: { pattern: /^\d{1,2}\.\d$/, type: 'decimal' },
        
        sunshineHours: { pattern: /^\d{1,2}\.\d$/, min: 0.0, max: 12.0, type: 'decimal' },
        totalCloudCover: { pattern: /^\d{1,2}$/, min: 0, max: 8, type: 'integer' },
        lowCloudCover: { pattern: /^\d{1,2}$/, min: 0, max: 8, type: 'integer' },
        
        precipitation: { pattern: /^\d{1,3}\.\d$/, type: 'precipitation' },
        maxWindSpeed: { pattern: /^\d{1,2}$/, min: 0, max: 36, type: 'integer' },
        classAEvaporation: { pattern: /^\d{1,2}\.\d$/, type: 'decimal' },
        avgWindSpeed2m: { pattern: /^\d{1,2}\.\d$/, min: 0.0, max: 36.0, type: 'decimal' },
        
        logEvaporation: { pattern: /^\d{1,2}\.\d$/, type: 'decimal' }
    };
}

function initFieldValidation() {
    const validationRules = getValidationRules();

    Object.keys(validationRules).forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field) {
            field.addEventListener('blur', function() {
                validateField(fieldId, validationRules[fieldId]);
            });
            
            field.addEventListener('input', function() {
                enforceMaxLength(field, validationRules[fieldId].type);
            });
        }
    });
}

// التحكم في الطول الأقصى للحقول
function enforceMaxLength(field, type) {
    let maxLength;
    
    switch(type) {
        case 'temperature':
            maxLength = 5;
            break;
        case 'humidity':
            maxLength = 3;
            break;
        case 'decimal':
            maxLength = 4;
            break;
        case 'precipitation':
            maxLength = 5;
            break;
        case 'integer':
            maxLength = 2;
            break;
        default:
            maxLength = field.getAttribute('maxlength') || 10;
    }
    
    if (field.value.length > maxLength) {
        field.value = field.value.substring(0, maxLength);
    }
}

// التحقق من صحة حقل
function validateField(fieldId, rules) {
    const field = document.getElementById(fieldId);
    const errorElement = document.getElementById(fieldId + 'Error');
    const successElement = document.getElementById(fieldId + 'Success');
    
    if (!field || !errorElement || !successElement) return;
    
    const value = field.value.trim();
    
    if (!value) {
        errorElement.style.display = 'none';
        successElement.style.display = 'none';
        field.classList.remove('field-valid', 'field-invalid');
        return;
    }
    
    if (!rules.pattern.test(value)) {
        if (fieldId.includes('Humidity')) {
            showError(field, errorElement, successElement, 'يجب إدخال 3 أرقام (مثال: 070 أو 085 أو 100)');
        } else if (fieldId.includes('Temp') || fieldId.includes('temperature')) {
            showError(field, errorElement, successElement, 'يجب إدخال قيمة بصيغة: ±dd.d (مثال: +25.5 أو -05.3)');
        } else {
            showError(field, errorElement, successElement, 'الصيغة غير صحيحة');
        }
        return;
    }
    
    const numericValue = parseFloat(value);
    if (rules.min !== undefined && numericValue < rules.min) {
        showError(field, errorElement, successElement, `القيمة أقل من الحد الأدنى (${rules.min})`);
        return;
    }
    
    if (rules.max !== undefined && numericValue > rules.max) {
        showError(field, errorElement, successElement, `القيمة أكبر من الحد الأقصى (${rules.max})`);
        return;
    }
    
    showSuccess(field, errorElement, successElement);
}

// عرض رسالة الخطأ
function showError(field, errorElement, successElement, message) {
    errorElement.textContent = message;
    errorElement.style.display = 'block';
    successElement.style.display = 'none';
    field.classList.remove('field-valid');
    field.classList.add('field-invalid');
}

// عرض رسالة النجاح
function showSuccess(field, errorElement, successElement) {
    errorElement.style.display = 'none';
    successElement.style.display = 'block';
    field.classList.remove('field-invalid');
    field.classList.add('field-valid');
}

// ===== أزرار الإشارة =====

function initSignButtons() {
    const signButtons = document.querySelectorAll('.sign-btn');
    
    signButtons.forEach(button => {
        button.addEventListener('click', function() {
            const sign = this.getAttribute('data-sign');
            const inputContainer = this.closest('.input-with-sign');
            const input = inputContainer.querySelector('input');
            
            const buttonsInGroup = inputContainer.querySelectorAll('.sign-btn');
            buttonsInGroup.forEach(btn => btn.classList.remove('active'));
            
            this.classList.add('active');
            
            let currentValue = input.value;
            
            if (currentValue.startsWith('+') || currentValue.startsWith('-')) {
                currentValue = currentValue.substring(1);
            }
            
            if (sign === '-') {
                input.value = '-' + currentValue;
            } else {
                input.value = currentValue;
            }
            
            const event = new Event('blur');
            input.dispatchEvent(event);
        });
    });
}

// ===== أزرار الإجراءات =====

function initActionButtons() {
    // زر حفظ المسودة
    const saveDraftBtn = document.getElementById('saveDraftBtn');
    if (saveDraftBtn) {
        saveDraftBtn.addEventListener('click', async function() {
            const result = await saveDraft();
            if (result.success) {
                showNotification('تم حفظ المسودة بنجاح', 'success');
            } else {
                showNotification('حدث خطأ أثناء حفظ المسودة', 'error');
            }
        });
    }
    
    // زر إدخال بيانات تجريبية
    const testDataBtn = document.getElementById('testDataBtn');
    if (testDataBtn) {
        testDataBtn.addEventListener('click', function() {
            fillTestData();
            showNotification('تم تعبئة البيانات التجريبية بنجاح', 'success');
        });
    }
    
    // زر إرسال التقرير - تم تحديثه لإصلاح مشكلة formData
    const form = document.getElementById('agriculturalReportForm');
    if (form) {
        form.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            // التحقق من صحة النموذج
            if (!validateForm()) {
                showNotification('يوجد أخطاء في البيانات، يرجى تصحيحها قبل الإرسال', 'error');
                return;
            }
            
            // التحقق من الموافقة على المسؤولية
            const agreement = document.getElementById('responsibilityAgreement');
            if (!agreement?.checked) {
                showNotification('يجب الموافقة على بيان المسؤولية قبل الإرسال', 'error');
                return;
            }
            
            // التحقق من بيانات المستخدم
            if (!currentUserData || !currentUserData.id) {
                showNotification('يجب تسجيل الدخول لإرسال التقرير', 'error');
                return;
            }
            
            showLoading(true);
            
            // تعريف formData هنا ليكون متاحاً في catch
            let formData;
            let reportData;
            
            try {
                // جمع البيانات
                formData = collectFormData();
                reportData = prepareReportData(formData, 'submitted');
                
                console.log('🚀 إرسال التقرير الزراعي بالتاريخ الميلادي...', reportData.report_date);
                
                // إرسال البيانات إلى Supabase
                let result;
                
                if (isConnectedToSupabase && window.SupabaseHelper) {
                    result = await window.SupabaseHelper.saveReport(reportData);
                    
                    if (result.success) {
                        console.log('✅ تم إرسال التقرير إلى Supabase بنجاح بالتاريخ الميلادي');
                        if (typeof loadStationStatistics === 'function') {
                            loadStationStatistics();
                        }
                        showNotification('تم إرسال التقرير بنجاح إلى قاعدة البيانات (التاريخ الميلادي)', 'success');
                        
                        // حذف المسودة المحفوظة
                        localStorage.removeItem('agriculturalReportDraft');
                        
                        // إعادة تعيين النموذج
                        setTimeout(() => {
                            document.getElementById('agriculturalReportForm').reset();
                            resetValidationStates();
                            resetSignButtons();
                            
                            // إعادة تعيين التاريخ إلى اليوم الميلادي
                            const reportDateField = document.getElementById('reportDate');
                            if (reportDateField) {
                                const today = new Date();
                                const gregorianDate = today.toISOString().split('T')[0];
                                reportDateField.value = gregorianDate;
                            }
                        }, 2000);
                        
                    } else {
                        throw new Error(result.error?.message || 'خطأ في الإرسال');
                    }
                    
                } else {
                    // حفظ محلياً إذا لم يكن هناك اتصال
                    console.warn('⚠️ لا يوجد اتصال بـ Supabase، سيتم الحفظ محلياً');
                    
                    const failedSubmissions = JSON.parse(localStorage.getItem('agricultural_failed_submissions') || '[]');
                    failedSubmissions.push({
                        data: reportData,
                        timestamp: new Date().toISOString(),
                        status: 'pending'
                    });
                    localStorage.setItem('agricultural_failed_submissions', JSON.stringify(failedSubmissions));
                    
                    showNotification('تم حفظ التقرير محلياً (بالتاريخ الميلادي) وسيتم إرساله تلقائياً عند استعادة الاتصال', 'warning');
                    
                    // إعادة تعيين النموذج
                    setTimeout(() => {
                        document.getElementById('agriculturalReportForm').reset();
                        resetValidationStates();
                        resetSignButtons();
                        
                        // إعادة تعيين التاريخ إلى اليوم الميلادي
                        const reportDateField = document.getElementById('reportDate');
                        if (reportDateField) {
                            const today = new Date();
                            const gregorianDate = today.toISOString().split('T')[0];
                            reportDateField.value = gregorianDate;
                        }
                    }, 2000);
                }
                
            } catch (error) {
                console.error('❌ خطأ في إرسال التقرير:', error);
                
                let message = 'حدث خطأ أثناء إرسال التقرير';
                if (error.message.includes('date_format')) {
                    message = 'مشكلة في هيكل قاعدة البيانات: عمود date_format مفقود';
                } else if (error.message.includes('network') || error.message.includes('fetch')) {
                    message = 'خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت';
                } else if (error.message.includes('auth')) {
                    message = 'خطأ في المصادقة. يرجى تسجيل الدخول مرة أخرى';
                } else if (error.message.includes('duplicate')) {
                    message = 'تقرير لهذا التاريخ موجود بالفعل';
                } else if (error.message.includes('violates row-level security policy')) {
                    message = 'خطأ في الصلاحيات. يرجى التحقق من إعدادات الأمان';
                }
                
                showNotification(message + ': ' + error.message, 'error');
                
                // حفظ البيانات محلياً للاستعادة لاحقاً
                if (formData) {
                    saveLocalBackup(formData, error);
                }
                
            } finally {
                showLoading(false);
            }
        });
    }
}

// إضافة زر اختبار الإرسال
function addTestSubmitButton() {
    const buttonContainer = document.querySelector('.text-center.mt-4');
    if (buttonContainer) {
        const testBtn = document.createElement('button');
        testBtn.type = 'button';
        testBtn.className = 'btn btn-danger btn-custom';
        testBtn.id = 'testSubmitBtn';
        testBtn.innerHTML = '<i class="fas fa-bug me-1"></i>اختبار الإرسال';
        testBtn.addEventListener('click', testSubmit);
        buttonContainer.appendChild(testBtn);
    }
}

// حفظ المسودة
async function saveDraft() {
    try {
        const formData = collectFormData();
        const timestamp = new Date().toISOString();
        const draftData = {
            data: formData,
            timestamp: timestamp,
            reportDate: convertToGregorianDate(document.getElementById('reportDate').value),
            status: 'draft'
        };
        
        // حفظ محلياً
        localStorage.setItem('agriculturalReportDraft', JSON.stringify(draftData));
        
        // محاولة الحفظ في Supabase إذا كان متصلاً
        if (isConnectedToSupabase && currentUserData) {
            const reportData = prepareReportData(formData, 'draft');
            
            if (window.SupabaseHelper) {
                const result = await window.SupabaseHelper.saveReport(reportData);
                if (result.success) {
                    console.log('✅ تم حفظ المسودة في Supabase');
                }
            }
        }
        
        return { success: true };
        
    } catch (error) {
        console.error('خطأ في حفظ المسودة:', error);
        return { success: false, error: error.message };
    }
}

// تعبئة البيانات التجريبية
function fillTestData() {
    const userStation = document.getElementById('userStation').textContent;
    const userName = document.getElementById('userName').textContent;
    const userRole = document.getElementById('userRole').textContent;
    
    const testData = {
        avgAirTemp: '+25.5',
        maxAirTemp: '+32.1',
        minAirTemp: '+18.3',
        minTemp2m: '+17.8',
        maxSoilSurfaceTemp: '+45.2',
        minSoilSurfaceTemp: '+15.6',
        avgHumidity: '075',
        minHumidity: '045',
        avgEsE: '12.3',
        minEsE: '08.7',
        sunshineHours: '09.5',
        totalCloudCover: '03',
        lowCloudCover: '02',
        precipitation: '000.0',
        maxWindSpeed: '15',
        classAEvaporation: '08.2',
        avgWindSpeed2m: '05.7',
        avgSoilTemp5cm: '+24.3',
        avgSoilTemp10cm: '+23.1',
        avgSoilTemp20cm: '+21.8',
        avgSoilTemp50cm: '+20.5',
        fieldSoilTemp5cm: '+25.1',
        fieldSoilTemp10cm: '+23.9',
        logEvaporation: '07.5',
        dew: '1',
        fog: '0',
        hail: '0',
        sandstorm: '0',
        observerNotes: `هذه بيانات تجريبية لأغراض الاختبار فقط.\nالمحطة: ${userStation}\nالراصد: ${userName}\nالصفة: ${userRole}\nالتاريخ الميلادي: ${new Date().toISOString().split('T')[0]}`
    };
    
    Object.keys(testData).forEach(key => {
        const field = document.getElementById(key);
        if (field && testData[key] !== null && testData[key] !== undefined) {
            field.value = testData[key];
            
            const event = new Event('blur');
            field.dispatchEvent(event);
        }
    });
    
    const positiveFields = ['avgAirTemp', 'maxAirTemp', 'minAirTemp', 'minTemp2m', 'maxSoilSurfaceTemp', 
                           'minSoilSurfaceTemp', 'avgSoilTemp5cm', 'avgSoilTemp10cm', 'avgSoilTemp20cm', 
                           'avgSoilTemp50cm', 'fieldSoilTemp5cm', 'fieldSoilTemp10cm'];
    
    positiveFields.forEach(fieldId => {
        const inputContainer = document.getElementById(fieldId)?.closest('.input-with-sign');
        if (inputContainer) {
            const plusButton = inputContainer.querySelector('.sign-btn[data-sign="+"]');
            if (plusButton) {
                plusButton.click();
            }
        }
    });
}

// جمع بيانات النموذج
function collectFormData() {
    const userStation = document.getElementById('userStation').textContent;
    const userName = document.getElementById('userName').textContent;
    const userRole = document.getElementById('userRole').textContent;
    
    const formData = {
        // بيانات المستخدم
        user_id: currentUserData?.id || 'unknown',
        user_name: userName,
        user_station: userStation,
        user_role: userRole,
        user_email: currentUserData?.email || 'unknown@example.com',
        
        // بيانات النموذج
        avgAirTemp: document.getElementById('avgAirTemp')?.value || '',
        maxAirTemp: document.getElementById('maxAirTemp')?.value || '',
        minAirTemp: document.getElementById('minAirTemp')?.value || '',
        minTemp2m: document.getElementById('minTemp2m')?.value || '',
        maxSoilSurfaceTemp: document.getElementById('maxSoilSurfaceTemp')?.value || '',
        minSoilSurfaceTemp: document.getElementById('minSoilSurfaceTemp')?.value || '',
        avgHumidity: document.getElementById('avgHumidity')?.value || '',
        minHumidity: document.getElementById('minHumidity')?.value || '',
        avgEsE: document.getElementById('avgEsE')?.value || '',
        minEsE: document.getElementById('minEsE')?.value || '',
        sunshineHours: document.getElementById('sunshineHours')?.value || '',
        totalCloudCover: document.getElementById('totalCloudCover')?.value || '',
        lowCloudCover: document.getElementById('lowCloudCover')?.value || '',
        precipitation: document.getElementById('precipitation')?.value || '',
        maxWindSpeed: document.getElementById('maxWindSpeed')?.value || '',
        classAEvaporation: document.getElementById('classAEvaporation')?.value || '',
        avgWindSpeed2m: document.getElementById('avgWindSpeed2m')?.value || '',
        avgSoilTemp5cm: document.getElementById('avgSoilTemp5cm')?.value || '',
        avgSoilTemp10cm: document.getElementById('avgSoilTemp10cm')?.value || '',
        avgSoilTemp20cm: document.getElementById('avgSoilTemp20cm')?.value || '',
        avgSoilTemp50cm: document.getElementById('avgSoilTemp50cm')?.value || '',
        fieldSoilTemp5cm: document.getElementById('fieldSoilTemp5cm')?.value || '',
        fieldSoilTemp10cm: document.getElementById('fieldSoilTemp10cm')?.value || '',
        logEvaporation: document.getElementById('logEvaporation')?.value || '',
        dew: document.getElementById('dew')?.value || '',
        fog: document.getElementById('fog')?.value || '',
        hail: document.getElementById('hail')?.value || '',
        sandstorm: document.getElementById('sandstorm')?.value || '',
        observerNotes: document.getElementById('observerNotes')?.value || '',
        
        // بيانات إضافية (التاريخ الميلادي)
        currentDate: new Date().toISOString().split('T')[0], // تاريخ اليوم الميلادي
        reportDate: convertToGregorianDate(document.getElementById('reportDate')?.value || '') // تاريخ التقرير الميلادي
    };
    
    console.log('📅 التاريخ الميلادي للإرسال:', formData.reportDate);
    return formData;
}

// تحضير بيانات التقرير للإرسال (محدث بدون date_format)
function prepareReportData(formData, status = 'submitted') {
    const reportData = {
        // بيانات المستخدم
        user_id: formData.user_id,
        user_name: formData.user_name,
        station: formData.user_station,
        user_role: formData.user_role,
        user_email: formData.user_email,
        
        // التاريخ (الميلادي فقط)
        report_date: formData.reportDate,
        submission_date: new Date().toISOString(),
        
        // درجات الحرارة
        avg_air_temp: formData.avgAirTemp ? parseFloat(formData.avgAirTemp) : null,
        max_air_temp: formData.maxAirTemp ? parseFloat(formData.maxAirTemp) : null,
        min_air_temp: formData.minAirTemp ? parseFloat(formData.minAirTemp) : null,
        min_temp_2m: formData.minTemp2m ? parseFloat(formData.minTemp2m) : null,
        max_soil_surface_temp: formData.maxSoilSurfaceTemp ? parseFloat(formData.maxSoilSurfaceTemp) : null,
        min_soil_surface_temp: formData.minSoilSurfaceTemp ? parseFloat(formData.minSoilSurfaceTemp) : null,
        
        // الرطوبة
        avg_humidity: formData.avgHumidity ? parseInt(formData.avgHumidity) : null,
        min_humidity: formData.minHumidity ? parseInt(formData.minHumidity) : null,
        avg_es_e: formData.avgEsE ? parseFloat(formData.avgEsE) : null,
        min_es_e: formData.minEsE ? parseFloat(formData.minEsE) : null,
        
        // السطوع الشمسي والغيوم
        sunshine_hours: formData.sunshineHours ? parseFloat(formData.sunshineHours) : null,
        total_cloud_cover: formData.totalCloudCover ? parseInt(formData.totalCloudCover) : null,
        low_cloud_cover: formData.lowCloudCover ? parseInt(formData.lowCloudCover) : null,
        
        // الهطول والرياح
        precipitation: formData.precipitation ? parseFloat(formData.precipitation) : null,
        max_wind_speed: formData.maxWindSpeed ? parseInt(formData.maxWindSpeed) : null,
        class_a_evaporation: formData.classAEvaporation ? parseFloat(formData.classAEvaporation) : null,
        avg_wind_speed_2m: formData.avgWindSpeed2m ? parseFloat(formData.avgWindSpeed2m) : null,
        
        // درجات حرارة التربة
        avg_soil_temp_5cm: formData.avgSoilTemp5cm ? parseFloat(formData.avgSoilTemp5cm) : null,
        avg_soil_temp_10cm: formData.avgSoilTemp10cm ? parseFloat(formData.avgSoilTemp10cm) : null,
        avg_soil_temp_20cm: formData.avgSoilTemp20cm ? parseFloat(formData.avgSoilTemp20cm) : null,
        avg_soil_temp_50cm: formData.avgSoilTemp50cm ? parseFloat(formData.avgSoilTemp50cm) : null,
        field_soil_temp_5cm: formData.fieldSoilTemp5cm ? parseFloat(formData.fieldSoilTemp5cm) : null,
        field_soil_temp_10cm: formData.fieldSoilTemp10cm ? parseFloat(formData.fieldSoilTemp10cm) : null,
        log_evaporation: formData.logEvaporation ? parseFloat(formData.logEvaporation) : null,
        
        // الظواهر الجوية
        dew: formData.dew === '1' || formData.dew === true || formData.dew === 'true',
        fog: formData.fog === '1' || formData.fog === true || formData.fog === 'true',
        hail: formData.hail === '1' || formData.hail === true || formData.hail === 'true',
        sandstorm: formData.sandstorm === '1' || formData.sandstorm === true || formData.sandstorm === 'true',
        
        // الملاحظات
        observer_notes: formData.observerNotes || '',
        
        // حالة التقرير
        status: status,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
    };
    
    console.log('📤 بيانات التقرير النهائية:', reportData.report_date);
    return reportData;
}

// دالة اختبار الإرسال
async function testSubmit() {
    try {
        showNotification('جاري اختبار الإرسال...', 'info');
        showLoading(true);
        
        const formData = collectFormData();
        console.log('📦 بيانات النموذج المجمعة:', formData);
        
        const reportData = prepareReportData(formData, 'test');
        console.log('📦 بيانات التقرير المعدة:', reportData);
        
        if (window.SupabaseHelper) {
            console.log('🔧 جاري الإرسال عبر SupabaseHelper...');
            const result = await window.SupabaseHelper.saveReport(reportData);
            
            if (result.success) {
                showNotification('✅ تم الإرسال بنجاح!', 'success');
                console.log('✅ تم الإرسال:', result.data);
            } else {
                showNotification('❌ فشل الإرسال: ' + (result.error?.message || 'خطأ غير معروف'), 'error');
                console.error('❌ خطأ الإرسال:', result.error);
            }
        } else {
            showNotification('❌ SupabaseHelper غير متاح', 'error');
            console.error('❌ SupabaseHelper غير معرف');
        }
        
    } catch (error) {
        console.error('❌ خطأ في الاختبار:', error);
        showNotification('❌ خطأ: ' + error.message, 'error');
    } finally {
        showLoading(false);
    }
}

// ===== إعادة تعيين حالات التحقق =====
function resetValidationStates() {
    const fields = document.querySelectorAll('.input-mask, .form-select');
    const errorMessages = document.querySelectorAll('.error-message');
    const successMessages = document.querySelectorAll('.success-message');
    
    fields.forEach(field => {
        field.classList.remove('field-valid', 'field-invalid');
        field.classList.remove('auto-formatted', 'needs-review', 'format-error');
    });
    
    errorMessages.forEach(msg => {
        msg.style.display = 'none';
    });
    
    successMessages.forEach(msg => {
        msg.style.display = 'none';
    });
}

// إعادة تعيين أزرار الإشارة
function resetSignButtons() {
    const signButtons = document.querySelectorAll('.sign-btn');
    signButtons.forEach(button => {
        button.classList.remove('active');
    });
}

// تحميل المسودة المحفوظة
function loadDraft() {
    try {
        const draftData = localStorage.getItem('agriculturalReportDraft');
        if (draftData) {
            const draft = JSON.parse(draftData);
            
            Object.keys(draft.data).forEach(fieldId => {
                const field = document.getElementById(fieldId);
                if (field) {
                    field.value = draft.data[fieldId];
                    
                    const event = new Event('blur');
                    field.dispatchEvent(event);
                }
            });
            
            if (draft.reportDate) {
                // تحميل التاريخ الميلادي المحفوظ
                document.getElementById('reportDate').value = draft.reportDate;
            }
            
            showNotification('تم تحميل المسودة المحفوظة', 'info');
            return true;
        }
    } catch (error) {
        console.error('خطأ في تحميل المسودة:', error);
    }
    
    return false;
}

// ===== حفظ نسخة احتياطية محلية =====
function saveLocalBackup(formData, error) {
    try {
        const backups = JSON.parse(localStorage.getItem('agricultural_backups') || '[]');
        
        backups.push({
            data: formData,
            error: error?.message || 'خطأ غير معروف',
            timestamp: new Date().toISOString(),
            attempt: backups.length + 1
        });
        
        // الاحتفاظ بآخر 50 نسخة احتياطية فقط
        if (backups.length > 50) {
            backups.shift();
        }
        
        localStorage.setItem('agricultural_backups', JSON.stringify(backups));
        console.log('💾 تم حفظ نسخة احتياطية محلية');
        
    } catch (backupError) {
        console.error('❌ فشل حفظ النسخة الاحتياطية:', backupError);
    }
}

// ===== نظام عرض التقارير =====

function setupViewButtonsByRole() {
    const userRole = document.getElementById('userRole').textContent;
    const userStation = document.getElementById('userStation').textContent;
    
    if (userRole === 'رئيس محطة' || userRole === 'مدقق') {
        addViewButtons(userRole, userStation);
    }
}

function addViewButtons(userRole, userStation) {
    const buttonContainer = document.querySelector('.text-center.mt-4');
    if (!buttonContainer) return;
    
    const viewButtonsDiv = document.createElement('div');
    viewButtonsDiv.className = 'view-buttons-container';
    viewButtonsDiv.innerHTML = `
        <h5 class="text-center mb-3">
            <i class="fas fa-chart-bar me-2"></i>عرض التقارير
        </h5>
        <div class="row g-2">
            ${userRole === 'رئيس محطة' ? `
            <div class="col-md-6">
                <button type="button" class="btn btn-info w-100" id="viewStationReports">
                    <i class="fas fa-building me-1"></i>تقارير محطتي
                </button>
            </div>
            ` : ''}
            ${userRole === 'مدقق' ? `
            <div class="col-md-6">
                <button type="button" class="btn btn-warning w-100" id="viewAllReports">
                    <i class="fas fa-list me-1"></i>جميع التقارير
                </button>
            </div>
            ` : ''}
            <div class="col-md-6">
                <button type="button" class="btn btn-secondary w-100" id="viewMyReports">
                    <i class="fas fa-user me-1"></i>تقاريري
                </button>
            </div>
        </div>
        ${userRole === 'مدقق' ? `
        <div class="row g-2 mt-2">
            <div class="col-12">
                <div class="input-group">
                    <span class="input-group-text"><i class="fas fa-search"></i></span>
                    <input type="text" class="form-control" id="searchStation" placeholder="بحث باسم المحطة...">
                    <button class="btn btn-outline-primary" type="button" id="searchStationBtn">بحث</button>
                </div>
            </div>
        </div>
        ` : ''}
    `;
    
    buttonContainer.parentNode.insertBefore(viewButtonsDiv, buttonContainer);
    
    addViewButtonsEventListeners(userRole, userStation);
}

function addViewButtonsEventListeners(userRole, userStation) {
    const viewStationReportsBtn = document.getElementById('viewStationReports');
    if (viewStationReportsBtn) {
        viewStationReportsBtn.addEventListener('click', function() {
            loadStationReports(userStation);
        });
    }
    
    const viewAllReportsBtn = document.getElementById('viewAllReports');
    if (viewAllReportsBtn) {
        viewAllReportsBtn.addEventListener('click', function() {
            loadAllReports();
        });
    }
    
    const viewMyReportsBtn = document.getElementById('viewMyReports');
    if (viewMyReportsBtn) {
        viewMyReportsBtn.addEventListener('click', function() {
            loadMyReports();
        });
    }
    
    const searchStationBtn = document.getElementById('searchStationBtn');
    if (searchStationBtn) {
        searchStationBtn.addEventListener('click', function() {
            const searchTerm = document.getElementById('searchStation').value;
            searchReportsByStation(searchTerm);
        });
    }
}
async function loadStationStatistics () {
  const statsLoading = document.getElementById ('statsLoading');
  const statsGrid = document.getElementById ('statsGrid');
  const userStation = document.getElementById ('userStation').textContent;

  try {
    if (!window.supabase) return;

    // 1. جلب إجمالي النشرات الزراعية
    const {count: totalCount, error: totalError} = await supabase
      .from ('agricultural_reports')
      .select ('*', {count: 'exact', head: true})
      .eq ('station', userStation);

    // 2. جلب نشرات اليوم
    const today = new Date ().toISOString ().split ('T')[0];
    const {count: todayCount, error: todayError} = await supabase
      .from ('agricultural_reports')
      .select ('*', {count: 'exact', head: true})
      .eq ('station', userStation)
      .eq ('report_date', today);

    if (totalError || todayError) throw totalError || todayError;

    // تحديث المعرفات في الـ HTML (تأكد من وجود هذه الـ IDs)
    document.getElementById ('totalReportsCount').textContent = totalCount || 0;
    document.getElementById ('todayReportsCount').textContent = todayCount || 0;

    if (statsLoading) statsLoading.style.display = 'none';
    if (statsGrid) statsGrid.style.display = 'grid';
  } catch (error) {
    console.error ('Error:', error);
  }
}

async function loadAllReports() {
    try {
        showLoading(true);
        
        if (!isConnectedToSupabase || !window.SupabaseHelper) {
            throw new Error('غير متصل بقاعدة البيانات');
        }
        
        const result = await window.SupabaseHelper.getReports();
        
        if (result.success) {
            displayReports(result.data, 'جميع التقارير الزراعية');
        } else {
            throw new Error(result.error?.message || 'خطأ في تحميل التقارير');
        }
        
    } catch (error) {
        console.error('❌ خطأ في تحميل جميع التقارير:', error);
        showNotification('حدث خطأ في تحميل التقارير', 'error');
    } finally {
        showLoading(false);
    }
}

async function loadMyReports() {
    try {
        showLoading(true);
        
        if (!isConnectedToSupabase || !window.SupabaseHelper || !currentUserData) {
            throw new Error('غير متصل بقاعدة البيانات أو لم يتم تسجيل الدخول');
        }
        
        const result = await window.SupabaseHelper.getReports({ user_id: currentUserData.id });
        
        if (result.success) {
            displayReports(result.data, 'تقاريري الشخصية');
        } else {
            throw new Error(result.error?.message || 'خطأ في تحميل التقارير');
        }
        
    } catch (error) {
        console.error('❌ خطأ في تحميل تقاريري:', error);
        showNotification('حدث خطأ في تحميل التقارير', 'error');
    } finally {
        showLoading(false);
    }
}

async function searchReportsByStation(stationName) {
    try {
        if (!stationName.trim()) {
            showNotification('يرجى إدخال اسم المحطة للبحث', 'warning');
            return;
        }
        
        showLoading(true);
        
        if (!isConnectedToSupabase || !window.SupabaseHelper) {
            throw new Error('غير متصل بقاعدة البيانات');
        }
        
        const result = await window.SupabaseHelper.getReports({ station: stationName });
        
        if (result.success) {
            displayReports(result.data, `نتائج البحث عن: ${stationName}`);
        } else {
            throw new Error(result.error?.message || 'خطأ في البحث');
        }
        
    } catch (error) {
        console.error('❌ خطأ في البحث:', error);
        showNotification('حدث خطأ أثناء البحث', 'error');
    } finally {
        showLoading(false);
    }
}

function displayReports(reports, title) {
    const modalId = 'reportsModal';
    let modal = document.getElementById(modalId);
    
    if (!modal) {
        modal = document.createElement('div');
        modal.className = 'modal fade';
        modal.id = modalId;
        modal.innerHTML = `
            <div class="modal-dialog modal-xl">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="reportsModalLabel">${title}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div id="reportsContent"></div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">إغلاق</button>
                        <button type="button" class="btn btn-primary" id="exportReportsBtn">
                            <i class="fas fa-download me-1"></i>تصدير البيانات
                        </button>
                    </div>
                </div>
            </div>
        `;
        document.body.appendChild(modal);
        
        document.getElementById('exportReportsBtn').addEventListener('click', function() {
            exportReportsToExcel(reports, title);
        });
    }
    
    document.getElementById('reportsModalLabel').textContent = title;
    const reportsContent = document.getElementById('reportsContent');
    reportsContent.innerHTML = generateReportsHTML(reports);
    
    const bsModal = new bootstrap.Modal(modal);
    bsModal.show();
}

function generateReportsHTML(reports) {
    if (!reports || reports.length === 0) {
        return `
            <div class="alert alert-info text-center">
                <i class="fas fa-info-circle me-2"></i>
                لا توجد تقارير لعرضها
            </div>
        `;
    }
    
    return `
        <div class="table-responsive">
            <table class="table table-striped table-hover reports-table">
                <thead class="table-dark">
                    <tr>
                        <th>#</th>
                        <th>المحطة</th>
                        <th>الراصد</th>
                        <th>التاريخ الميلادي</th>
                        <th>درجة الحرارة</th>
                        <th>الرطوبة</th>
                        <th>الهطول</th>
                        <th>الحالة</th>
                        <th>الإجراءات</th>
                    </tr>
                </thead>
                <tbody>
                    ${reports.map((report, index) => `
                        <tr>
                            <td>${index + 1}</td>
                            <td>${report.station || 'غير محدد'}</td>
                            <td>${report.user_name || 'غير معروف'}</td>
                            <td>${formatGregorianDateForDisplay(report.report_date)}</td>
                            <td>${report.avg_air_temp || '--'}°C</td>
                            <td>${report.avg_humidity || '--'}%</td>
                            <td>${report.precipitation || '--'} مم</td>
                            <td>
                                <span class="badge bg-${report.status === 'submitted' ? 'success' : 'warning'}">
                                    ${report.status === 'submitted' ? 'مرسل' : 'مسودة'}
                                </span>
                            </td>
                            <td>
                                <button class="btn btn-sm btn-outline-primary view-report-details" 
                                        data-report-id="${report.id}">
                                    <i class="fas fa-eye"></i>
                                </button>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
        <div class="mt-3">
            <p class="text-muted">
                <i class="fas fa-info-circle me-1"></i>
                إجمالي عدد التقارير: <strong>${reports.length}</strong>
                <br>
                <small>جميع التواريخ معروضة بالميلادي</small>
            </p>
        </div>
    `;
}

// تنسيق التاريخ الميلادي للعرض
function formatGregorianDateForDisplay(dateString) {
    if (!dateString) return '--';
    try {
        const date = new Date(dateString);
        return date.toLocaleDateString('en-GB', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        }).split('/').join('-');
    } catch (error) {
        return dateString;
    }
}

function setupReportDetailsView() {
    document.addEventListener('click', function(e) {
        if (e.target.closest('.view-report-details')) {
            const reportId = e.target.closest('.view-report-details').getAttribute('data-report-id');
            showReportDetails(reportId);
        }
    });
}

async function showReportDetails(reportId) {
    try {
        showLoading(true);
        
        if (!isConnectedToSupabase || !window.SupabaseHelper) {
            throw new Error('غير متصل بقاعدة البيانات');
        }
        
        const result = await window.SupabaseHelper.getReportById(reportId);
        
        if (result.success) {
            const report = result.data;
            
            const detailsModalId = 'reportDetailsModal';
            let detailsModal = document.getElementById(detailsModalId);
            
            if (!detailsModal) {
                detailsModal = document.createElement('div');
                detailsModal.className = 'modal fade';
                detailsModal.id = detailsModalId;
                detailsModal.innerHTML = `
                    <div class="modal-dialog modal-lg">
                        <div class="modal-content">
                            <div class="modal-header">
                                <h5 class="modal-title">تفاصيل التقرير الزراعي</h5>
                                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                            </div>
                            <div class="modal-body" id="reportDetailsContent"></div>
                            <div class="modal-footer">
                                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">إغلاق</button>
                            </div>
                        </div>
                    </div>
                `;
                document.body.appendChild(detailsModal);
            }
            
            document.getElementById('reportDetailsContent').innerHTML = generateReportDetailsHTML(report);
            
            const bsModal = new bootstrap.Modal(detailsModal);
            bsModal.show();
            
        } else {
            throw new Error(result.error?.message || 'خطأ في تحميل التفاصيل');
        }
        
    } catch (error) {
        console.error('❌ خطأ في تحميل تفاصيل التقرير:', error);
        showNotification('حدث خطأ في تحميل التفاصيل', 'error');
    } finally {
        showLoading(false);
    }
}

function generateReportDetailsHTML(report) {
    return `
        <div class="row">
            <div class="col-md-6">
                <div class="report-details-section">
                    <h6>معلومات الأساسية</h6>
                    <table class="table table-sm">
                        <tr><td><strong>المحطة:</strong></td><td>${report.station}</td></tr>
                        <tr><td><strong>الراصد:</strong></td><td>${report.user_name}</td></tr>
                        <tr><td><strong>صفة العمل:</strong></td><td>${report.user_role}</td></tr>
                        <tr><td><strong>التاريخ الميلادي:</strong></td><td>${formatGregorianDateForDisplay(report.report_date)}</td></tr>
                        <tr><td><strong>تاريخ الإرسال:</strong></td><td>${formatDateTime(report.created_at)}</td></tr>
                    </table>
                </div>
            </div>
            <div class="col-md-6">
                <div class="report-details-section">
                    <h6>البيانات المناخية</h6>
                    <table class="table table-sm">
                        <tr><td><strong>متوسط الحرارة:</strong></td><td>${report.avg_air_temp || '--'}°C</td></tr>
                        <tr><td><strong>أعلى حرارة:</strong></td><td>${report.max_air_temp || '--'}°C</td></tr>
                        <tr><td><strong>أقل حرارة:</strong></td><td>${report.min_air_temp || '--'}°C</td></tr>
                        <tr><td><strong>متوسط الرطوبة:</strong></td><td>${report.avg_humidity || '--'}%</td></tr>
                        <tr><td><strong>كمية الهطول:</strong></td><td>${report.precipitation || '--'} مم</td></tr>
                    </table>
                </div>
            </div>
        </div>
        
        <div class="row mt-3">
            <div class="col-12">
                <div class="report-details-section">
                    <h6>الظواهر الجوية</h6>
                    <div class="d-flex gap-3 flex-wrap">
                        <span class="badge bg-${report.dew ? 'info' : 'secondary'}">ندى: ${report.dew ? 'نعم' : 'لا'}</span>
                        <span class="badge bg-${report.fog ? 'info' : 'secondary'}">ضباب: ${report.fog ? 'نعم' : 'لا'}</span>
                        <span class="badge bg-${report.hail ? 'danger' : 'secondary'}">برد: ${report.hail ? 'نعم' : 'لا'}</span>
                        <span class="badge bg-${report.sandstorm ? 'warning' : 'secondary'}">عواصف: ${report.sandstorm ? 'نعم' : 'لا'}</span>
                    </div>
                </div>
            </div>
        </div>
        
        ${report.observer_notes ? `
        <div class="row mt-3">
            <div class="col-12">
                <div class="report-details-section">
                    <h6>ملاحظات الراصد</h6>
                    <div class="alert alert-light border">
                        ${report.observer_notes}
                    </div>
                </div>
            </div>
        </div>
        ` : ''}
    `;
}

// ===== وظائف مساعدة =====

function formatDate(dateString) {
    if (!dateString) return '--';
    try {
        const date = new Date(dateString);
        return date.toLocaleDateString('ar-EG');
    } catch (error) {
        return dateString;
    }
}

function formatDateTime(dateString) {
    if (!dateString) return '--';
    try {
        const date = new Date(dateString);
        return date.toLocaleString('ar-EG');
    } catch (error) {
        return dateString;
    }
}

function exportReportsToExcel(reports, title) {
    try {
        // إنشاء بيانات CSV
        let csvContent = "data:text/csv;charset=utf-8,";
        
        // العناوين
        const headers = ["المحطة", "الراصد", "التاريخ الميلادي", "متوسط الحرارة", "الرطوبة", "الهطول", "الحالة"];
        csvContent += headers.join(",") + "\n";
        
        // البيانات
        reports.forEach(report => {
            const row = [
                `"${report.station || ''}"`,
                `"${report.user_name || ''}"`,
                `"${formatGregorianDateForDisplay(report.report_date)}"`,
                report.avg_air_temp || '',
                report.avg_humidity || '',
                report.precipitation || '',
                report.status === 'submitted' ? 'مرسل' : 'مسودة'
            ];
            csvContent += row.join(",") + "\n";
        });
        
        // إنشاء رابط التحميل
        const encodedUri = encodeURI(csvContent);
        const link = document.createElement("a");
        link.setAttribute("href", encodedUri);
        link.setAttribute("download", `${title.replace(/\s+/g, '_')}_${new Date().getTime()}.csv`);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        
        showNotification('تم تصدير البيانات بنجاح', 'success');
        
    } catch (error) {
        console.error('❌ خطأ في تصدير البيانات:', error);
        showNotification('حدث خطأ أثناء تصدير البيانات', 'error');
    }
}

// التحقق من صحة النموذج
function validateForm() {
    let isValid = true;
    
    // التحقق من الحقول المطلوبة
    const requiredFields = [
        'avgAirTemp', 'maxAirTemp', 'minAirTemp',
        'avgHumidity', 'dew', 'fog', 'hail', 'sandstorm'
    ];
    
    requiredFields.forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field) {
            const value = field.value ? field.value.trim() : '';
            
            if (!value || (field.classList && field.classList.contains('field-invalid'))) {
                isValid = false;
                
                if (field.classList) {
                    field.classList.add('field-invalid');
                }
                
                const errorElement = document.getElementById(fieldId + 'Error');
                if (errorElement) {
                    errorElement.textContent = 'هذا الحقل مطلوب';
                    errorElement.style.display = 'block';
                }
            }
        }
    });
    
    // التحقق من تاريخ التقرير
    const reportDateField = document.getElementById('reportDate');
    if (reportDateField && !reportDateField.value) {
        isValid = false;
        showNotification('يرجى اختيار تاريخ التقرير الميلادي', 'error');
    }
    
    // التحقق من صحة جميع الحقول
    const allInputs = document.querySelectorAll('.input-mask');
    allInputs.forEach(input => {
        if (input.classList.contains('field-invalid')) {
            isValid = false;
        }
    });
    
    return isValid;
}

// عرض الإشعارات
function showNotification(message, type = 'info') {
    const container = document.getElementById('notificationContainer');
    if (!container) return;
    
    const notification = document.createElement('div');
    notification.className = `alert alert-${type === 'success' ? 'success' : type === 'error' ? 'danger' : 'info'} alert-dismissible fade show`;
    notification.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    container.appendChild(notification);
    
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, 5000);
}

// عرض/إخفاء شاشة التحميل
function showLoading(show) {
    const loadingOverlay = document.getElementById('loadingOverlay');
    if (loadingOverlay) {
        if (show) {
            loadingOverlay.style.display = 'flex';
        } else {
            loadingOverlay.style.display = 'none';
        }
    }
}

// ===== دالات المساعدة الإضافية =====

// محاولة إعادة إرسال النسخ الاحتياطية
async function retryFailedSubmissions() {
    try {
        const backups = JSON.parse(localStorage.getItem('agricultural_backups') || '[]');
        
        if (backups.length === 0) {
            console.log('📭 لا توجد نسخ احتياطية لإعادة الإرسال');
            return;
        }
        
        console.log(`🔄 محاولة إعادة إرسال ${backups.length} نسخة احتياطية...`);
        
        const successful = [];
        const failed = [];
        
        for (let i = 0; i < backups.length; i++) {
            const backup = backups[i];
            
            try {
                const reportData = prepareReportData(backup.data, 'submitted');
                
                if (window.SupabaseHelper) {
                    const result = await window.SupabaseHelper.saveReport(reportData);
                    
                    if (result.success) {
                        successful.push(backup);
                        console.log(`✅ تمت إعادة إرسال النسخة الاحتياطية ${i + 1}`);
                    } else {
                        failed.push(backup);
                        console.warn(`⚠️ فشل إعادة إرسال النسخة الاحتياطية ${i + 1}`);
                    }
                }
            } catch (error) {
                failed.push(backup);
                console.error(`❌ خطأ في إعادة إرسال النسخة الاحتياطية ${i + 1}:`, error);
            }
        }
        
        // تحديث قائمة النسخ الاحتياطية
        localStorage.setItem('agricultural_backups', JSON.stringify(failed));
        
        if (successful.length > 0) {
            showNotification(`تمت إعادة إرسال ${successful.length} تقرير بنجاح`, 'success');
        }
        
        return { successful, failed };
        
    } catch (error) {
        console.error('❌ خطأ في عملية إعادة الإرسال:', error);
        return { successful: [], failed: [], error: error.message };
    }
}

// إنشاء تقرير إحصائي
function generateAgriculturalReport(reports) {
    if (!reports || reports.length === 0) {
        return null;
    }
    
    const stats = {
        totalReports: reports.length,
        stations: {},
        months: {},
        status: {
            submitted: 0,
            draft: 0
        },
        temperatureRange: {
            min: Infinity,
            max: -Infinity,
            avg: 0
        },
        humidityRange: {
            min: Infinity,
            max: -Infinity,
            avg: 0
        }
    };
    
    let tempSum = 0;
    let humiditySum = 0;
    let tempCount = 0;
    let humidityCount = 0;
    
    reports.forEach(report => {
        // إحصاءات المحطات
        const station = report.station || 'غير محدد';
        stats.stations[station] = (stats.stations[station] || 0) + 1;
        
        // إحصاءات الشهور الميلادية
        if (report.report_date) {
            const month = report.report_date.substring(0, 7); // YYYY-MM
            stats.months[month] = (stats.months[month] || 0) + 1;
        }
        
        // إحصاءات الحالة
        stats.status[report.status] = (stats.status[report.status] || 0) + 1;
        
        // إحصاءات درجة الحرارة
        if (report.avg_air_temp !== null) {
            stats.temperatureRange.min = Math.min(stats.temperatureRange.min, report.avg_air_temp);
            stats.temperatureRange.max = Math.max(stats.temperatureRange.max, report.avg_air_temp);
            tempSum += report.avg_air_temp;
            tempCount++;
        }
        
        // إحصاءات الرطوبة
        if (report.avg_humidity !== null) {
            stats.humidityRange.min = Math.min(stats.humidityRange.min, report.avg_humidity);
            stats.humidityRange.max = Math.max(stats.humidityRange.max, report.avg_humidity);
            humiditySum += report.avg_humidity;
            humidityCount++;
        }
    });
    
    // حساب المتوسطات
    if (tempCount > 0) {
        stats.temperatureRange.avg = tempSum / tempCount;
    }
    
    if (humidityCount > 0) {
        stats.humidityRange.avg = humiditySum / humidityCount;
    }
    
    return stats;
}
async function loadStationStatistics() {
    try {
        const userStationElement = document.getElementById('userStation');
        if (!userStationElement || !window.supabase) return;

        const userStation = userStationElement.textContent;

        // جلب الإجمالي من جدول agricultural_reports
        const { count: totalCount, error: totalErr } = await supabase
            .from('agricultural_reports')
            .select('*', { count: 'exact', head: true })
            .eq('station', userStation);

        // جلب تقارير اليوم
        const today = new Date().toISOString().split('T')[0];
        const { count: todayCount, error: todayErr } = await supabase
            .from('agricultural_reports')
            .select('*', { count: 'exact', head: true })
            .eq('station', userStation)
            .eq('report_date', today);

        if (!totalErr && !todayErr) {
            // تحديث العناصر في الصفحة
            const totalEl = document.getElementById('totalReportsCount');
            const todayEl = document.getElementById('todayReportsCount');
            
            if (totalEl) totalEl.textContent = totalCount || 0;
            if (todayEl) todayEl.textContent = todayCount || 0;

            // إظهار القسم وإخفاء التحميل
            document.getElementById('statsGrid').style.display = 'grid';
            document.getElementById('statsLoading').style.display = 'none';
        }
    } catch (error) {
        console.error("❌ فشل تحميل الإحصائيات:", error);
    }
}

// تنفيذ الدالة عند التحميل
document.addEventListener('DOMContentLoaded', () => {
    setTimeout(loadStationStatistics, 2000); // تأخير بسيط لضمان تحميل بيانات المستخدم
});

// جعل الدوال متاحة عالمياً
window.collectFormData = collectFormData;
window.prepareReportData = prepareReportData;
window.testSubmit = testSubmit;
window.updateAllDisplays = updateAllDisplays;
window.retryFailedSubmissions = retryFailedSubmissions;
window.generateAgriculturalReport = generateAgriculturalReport;
window.convertToGregorianDate = convertToGregorianDate;
window.formatGregorianDateForDisplay = formatGregorianDateForDisplay;
window.validateForm = validateForm;

console.log('✅ تم تحميل نظام النشرات الزراعية مع الربط بقاعدة البيانات بنجاح');
async function loadStationStatistics () {
  try {
    const userStationElement = document.getElementById ('userStation');
    if (!userStationElement || !window.supabase) return;

    const userStation = userStationElement.textContent;

    // جلب الإجمالي من جدول agricultural_reports
    const {count: totalCount, error: totalErr} = await supabase
      .from ('agricultural_reports')
      .select ('*', {count: 'exact', head: true})
      .eq ('station', userStation);

    // جلب تقارير اليوم
    const today = new Date ().toISOString ().split ('T')[0];
    const {count: todayCount, error: todayErr} = await supabase
      .from ('agricultural_reports')
      .select ('*', {count: 'exact', head: true})
      .eq ('station', userStation)
      .eq ('report_date', today);

    if (!totalErr && !todayErr) {
      // تحديث العناصر في الصفحة
      const totalEl = document.getElementById ('totalReportsCount');
      const todayEl = document.getElementById ('todayReportsCount');

      if (totalEl) totalEl.textContent = totalCount || 0;
      if (todayEl) todayEl.textContent = todayCount || 0;

      // إظهار القسم وإخفاء التحميل
      document.getElementById ('statsGrid').style.display = 'grid';
      document.getElementById ('statsLoading').style.display = 'none';
    }
  } catch (error) {
    console.error ('❌ فشل تحميل الإحصائيات:', error);
  }
}

// تنفيذ الدالة عند التحميل
document.addEventListener ('DOMContentLoaded', () => {
  setTimeout (loadStationStatistics, 2000); // تأخير بسيط لضمان تحميل بيانات المستخدم
});
