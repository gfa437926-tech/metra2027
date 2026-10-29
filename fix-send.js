// تهيئة Supabase
const supabase = window.supabase;

// بيانات القائمة
const menuItems = [
    { href: "../../../main.html", icon: "fa-chart-line", text: "لوحة التحكم" },
    { href: "../hourly/hourly_send/hourly_reports.html", icon: "fa-clock", text: "النشرات الساعية" },
    { href: "../daily/daily_send/daily.html", icon: "fa-calendar-days", text: "النشرات اليومية" },
    { href: "../rain/rain_send/rainfall_reports.html", icon: "fa-cloud-rain", text: "النشرات المطرية" },
    { href: "../h_climate/h_climate_send/climate_hourly_reports.html", icon: "fa-wind", text: "الساعي المناخي" },
    { href: "../soil/soil_send/soil-send.html", icon: "fa-temperature-half", text: "حرارة التربة" },
    { href: "../arg/send-argicultural/agricultural_reports.html", icon: "fa-leaf", text: "النشرات الزراعية" },
    { href: "fix.html", icon: "fa-microchip", text: "أعطال أجهزة الرصد" },
    { href: "fix-tel.html", icon: "fa-tower-cell", text: "مشاكل أجهزة الإتصالات", active: true },
    { href: "../../index.html", icon: "fa-right-from-bracket", text: "تسجيل الخروج", danger: true }
];

// بيانات الأعطال السابقة
const previousFailures = [
    { id: "#1234", type: "كمبيوتر", description: "لا يعمل الجهاز عند التشغيل", date: "2026-10-15", status: "in-progress" },
    { id: "#1233", type: "طابعة", description: "الطابعة لا تستجيب وتعطي أخطاء", date: "2026-10-14", status: "resolved" },
    { id: "#1232", type: "شبكة", description: "انقطاع في خدمة الإنترنت", date: "2026-10-13", status: "resolved" },
    { id: "#1231", type: "لابتوب", description: "مشكلة في شاشة اللابتوب", date: "2026-10-12", status: "pending" }
];

// دالة لتهيئة القوائم
function initializeMenus() {
    const sidebarMenu = document.getElementById('sidebarMenu');
    const mobileSidebarMenu = document.getElementById('mobileSidebarMenu');
    
    menuItems.forEach(item => {
        const menuItem = createMenuItem(item);
        sidebarMenu.appendChild(menuItem.cloneNode(true));
        mobileSidebarMenu.appendChild(menuItem);
    });
}

// دالة لإنشاء عنصر قائمة
function createMenuItem(item) {
    const li = document.createElement('li');
    li.className = 'nav-item mb-2';
    
    const link = document.createElement('a');
    link.className = `nav-link d-flex align-items-center ${item.active ? 'active' : ''} ${item.danger ? 'text-danger' : ''}`;
    link.href = item.href;
    
    link.innerHTML = `
        <i class="fa-solid ${item.icon} me-2" style="color:${item.danger ? '#ff0000' : '#009dff'};"></i>
        ${item.text}
    `;
    
    li.appendChild(link);
    return li;
}

// دالة لتحميل بيانات المستخدم
async function loadUserData() {
    try {
        console.log('🔄 جاري تحميل بيانات المستخدم...');
        
        // الحصول على المستخدم الحالي
        const { data: { user }, error: userError } = await supabase.auth.getUser();
        
        if (userError) {
            throw new Error(`خطأ في المصادقة: ${userError.message}`);
        }
        
        if (!user) {
            throw new Error('لم يتم العثور على مستخدم مسجل الدخول');
        }
        
        console.log('👤 المستخدم:', user);
        
        // جلب بيانات المستخدم من جدول الموظفين
        const { data: employeeData, error: employeeError } = await supabase
            .from('employees')
            .select('*')
            .eq('user_id', user.id)
            .single();
        
        if (employeeError) {
            console.warn('⚠️ لم يتم العثور على بيانات إضافية للمستخدم:', employeeError.message);
            // استخدام البيانات الأساسية من المصادقة
            displayUserData({
                full_name: user.user_metadata?.full_name || 'مستخدم',
                station: user.user_metadata?.station || 'غير محدد',
                role: user.user_metadata?.role || 'موظف'
            });
            return;
        }
        
        console.log('📊 بيانات الموظف:', employeeData);
        
        // جلب بيانات المحطة
        const { data: stationData, error: stationError } = await supabase
            .from('stations')
            .select('name_ar')
            .eq('id', employeeData.station_id)
            .single();
        
        if (stationError) {
            console.warn('⚠️ خطأ في جلب بيانات المحطة:', stationError.message);
        }
        
        // عرض بيانات المستخدم
        displayUserData({
            full_name: employeeData.full_name || 'مستخدم',
            station: stationData?.name_ar || employeeData.station_name || 'غير محدد',
            role: employeeData.role || 'موظف'
        });
        
    } catch (error) {
        console.error('❌ خطأ في تحميل بيانات المستخدم:', error);
        displayUserData({
            full_name: 'مستخدم',
            station: 'غير محدد',
            role: 'موظف'
        });
    }
}

// دالة لعرض بيانات المستخدم
function displayUserData(userData) {
    document.getElementById('userName').textContent = userData.full_name;
    document.getElementById('userStation').textContent = userData.station;
    document.getElementById('userRole').textContent = userData.role;
    
    // تحديث النماذج بمعلومات المستخدم
    updateFormsWithUserData(userData);
}

// دالة لتحديث النماذج بمعلومات المستخدم
function updateFormsWithUserData(userData) {
    const forms = [
        'computer', 'laptop', 'printer', 'network', 'communication', 'other'
    ];
    
    forms.forEach(formType => {
        const stationElement = document.getElementById(`${formType}StationName`);
        const reporterElement = document.getElementById(`${formType}ReporterName`);
        
        if (stationElement) stationElement.textContent = userData.station;
        if (reporterElement) reporterElement.textContent = userData.full_name;
    });
}

// دالة لتحميل الأعطال السابقة
function loadPreviousFailures() {
    const tbody = document.querySelector('#failuresTable tbody');
    
    previousFailures.forEach(failure => {
        const row = document.createElement('tr');
        
        let statusBadge = '';
        switch(failure.status) {
            case 'pending':
                statusBadge = '<span class="status-badge status-pending">معلق</span>';
                break;
            case 'in-progress':
                statusBadge = '<span class="status-badge status-in-progress">قيد المعالجة</span>';
                break;
            case 'resolved':
                statusBadge = '<span class="status-badge status-resolved">تم الإصلاح</span>';
                break;
        }
        
        row.innerHTML = `
            <td>${failure.id}</td>
            <td>${failure.type}</td>
            <td>${failure.description}</td>
            <td>${failure.date}</td>
            <td>${statusBadge}</td>
            <td>
                <button class="btn btn-sm btn-outline-primary">تفاصيل</button>
            </td>
        `;
        
        tbody.appendChild(row);
    });
}

// دالة لتهيئة النماذج
function initializeForms() {
    // إعداد أزرار الإرسال للنماذج
    const formConfig = [
        { id: 'submitComputerFailure', modal: 'computerModal', message: 'تم إرسال بلاغ عطل الكمبيوتر بنجاح!' },
        { id: 'submitLaptopFailure', modal: 'laptopModal', message: 'تم إرسال بلاغ عطل اللابتوب بنجاح!' },
        { id: 'submitPrinterFailure', modal: 'printerModal', message: 'تم إرسال بلاغ عطل الطابعة بنجاح!' },
        { id: 'submitNetworkFailure', modal: 'networkModal', message: 'تم إرسال بلاغ عطل الشبكة بنجاح!' },
        { id: 'submitCommunicationFailure', modal: 'communicationModal', message: 'تم إرسال بلاغ عطل الاتصالات بنجاح!' },
        { id: 'submitOtherFailure', modal: 'otherModal', message: 'تم إرسال بلاغ العطل بنجاح!' }
    ];
    
    formConfig.forEach(config => {
        const button = document.getElementById(config.id);
        if (button) {
            button.addEventListener('click', function() {
                alert(config.message);
                const modal = bootstrap.Modal.getInstance(document.getElementById(config.modal));
                if (modal) modal.hide();
            });
        }
    });
}

// دالة لتهيئة القائمة الجانبية للجوال
function initializeMobileMenu() {
    const mobileMenuBtn = document.getElementById('mobileMenuBtn');
    const mobileSidebar = document.getElementById('mobileSidebar');
    const mobileSidebarClose = document.getElementById('mobileSidebarClose');
    const mobileOverlay = document.getElementById('mobileOverlay');

    mobileMenuBtn.addEventListener('click', function () {
        mobileSidebar.classList.add('active');
        mobileOverlay.classList.add('active');
    });

    mobileSidebarClose.addEventListener('click', function () {
        mobileSidebar.classList.remove('active');
        mobileOverlay.classList.remove('active');
    });

    mobileOverlay.addEventListener('click', function () {
        mobileSidebar.classList.remove('active');
        mobileOverlay.classList.remove('active');
    });
}

// دالة رئيسية لتهيئة التطبيق
async function initializeApp() {
    try {
        console.log('🚀 بدء تهيئة التطبيق...');
        
        // تهيئة القوائم
        initializeMenus();
        
        // تهيئة القائمة الجانبية للجوال
        initializeMobileMenu();
        
        // تحميل بيانات المستخدم
        await loadUserData();
        
        // تحميل الأعطال السابقة
        loadPreviousFailures();
        
        // تهيئة النماذج
        initializeForms();
        
        // إخفاء شاشة التحميل وإظهار المحتوى الرئيسي
        setTimeout(function () {
            document.getElementById('loadingContainer').style.display = 'none';
            document.getElementById('mainContainer').style.display = 'block';
            console.log('✅ التطبيق جاهز للاستخدام');
        }, 1000);
        
    } catch (error) {
        console.error('❌ خطأ في تهيئة التطبيق:', error);
        document.getElementById('errorMessage').style.display = 'block';
    }
}

// إعداد زر إعادة المحاولة
document.getElementById('retryButton')?.addEventListener('click', function() {
    document.getElementById('errorMessage').style.display = 'none';
    initializeApp();
});

// بدء التطبيق عند تحميل الصفحة
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
});