// التهيئة الرئيسية للتطبيق
document.addEventListener('DOMContentLoaded', async function() {
    try {
        // إخفاء شاشة التحميل بعد التهيئة
        await initializeApplication();
        hideLoadingScreen();
        
    } catch (error) {
        console.error('Application initialization failed:', error);
        showLoadingError();
    }

    // إعداد معالجات الأحداث
    setupEventHandlers();
});

async function initializeApplication() {
    // تهيئة مدير المستخدم
    await userManager.initialize();
    
    // تهيئة معالج النماذج
    formHandler.setupEventListeners();
    
    // تحميل البيانات السابقة
    await loadPreviousFailures();
}

function setupEventHandlers() {
    // زر إعادة المحاولة
    const retryButton = document.getElementById('retryButton');
    if (retryButton) {
        retryButton.addEventListener('click', () => {
            location.reload();
        });
    }

    // زر تسجيل الخروج
    const logoutButtons = document.querySelectorAll('[href*="index.html"]');
    logoutButtons.forEach(button => {
        button.addEventListener('click', (e) => {
            e.preventDefault();
            userManager.logout();
        });
    });
}

async function loadPreviousFailures() {
    try {
        const user = userManager.getCurrentUser();
        const result = await database.getPreviousFailures(user?.id);
        
        if (result.success) {
            populateFailuresTable(result.data);
        } else {
            console.error('Failed to load failures:', result.error);
        }
    } catch (error) {
        console.error('Load failures error:', error);
    }
}

function populateFailuresTable(failures) {
    const tbody = document.getElementById('failuresTableBody');
    if (!tbody) return;

    tbody.innerHTML = '';

    failures.forEach(failure => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>#${failure.id}</td>
            <td>${getDeviceTypeText(failure.report_type)}</td>
            <td>${failure.description || 'لا يوجد وصف'}</td>
            <td>${formatDate(failure.created_at)}</td>
            <td>${getStatusBadge(failure.status)}</td>
            <td>
                <button class="btn btn-sm btn-outline-primary view-details" data-id="${failure.id}">
                    تفاصيل
                </button>
            </td>
        `;
        tbody.appendChild(row);
    });

    // إضافة معالجات الأحداث للأزرار
    tbody.querySelectorAll('.view-details').forEach(button => {
        button.addEventListener('click', (e) => {
            const reportId = e.target.getAttribute('data-id');
            showReportDetails(reportId);
        });
    });
}

function getDeviceTypeText(type) {
    const types = {
        [FAILURE_TYPES.COMPUTER]: 'كمبيوتر',
        [FAILURE_TYPES.LAPTOP]: 'لابتوب',
        [FAILURE_TYPES.PRINTER]: 'طابعة',
        [FAILURE_TYPES.NETWORK]: 'شبكة',
        [FAILURE_TYPES.PHONE]: 'هاتف',
        [FAILURE_TYPES.TOWER]: 'برج اتصالات',
        [FAILURE_TYPES.SATELLITE]: 'قمر صناعي',
        [FAILURE_TYPES.WIRELESS]: 'شبكة لاسلكية',
        [FAILURE_TYPES.FAX]: 'فاكس',
        [FAILURE_TYPES.OTHER]: 'أخرى'
    };
    return types[type] || type;
}

function getStatusBadge(status) {
    const badges = {
        [REPORT_STATUS.PENDING]: '<span class="status-badge status-pending">معلق</span>',
        [REPORT_STATUS.IN_PROGRESS]: '<span class="status-badge status-in-progress">قيد المعالجة</span>',
        [REPORT_STATUS.RESOLVED]: '<span class="status-badge status-resolved">تم الإصلاح</span>',
        [REPORT_STATUS.CANCELLED]: '<span class="status-badge status-cancelled">ملغي</span>'
    };
    return badges[status] || '<span class="status-badge status-pending">معلق</span>';
}

function formatDate(dateString) {
    return new Date(dateString).toLocaleDateString('ar-SA');
}

function hideLoadingScreen() {
    const loadingContainer = document.getElementById('loadingContainer');
    const mainContainer = document.getElementById('mainContainer');
    
    if (loadingContainer) loadingContainer.style.display = 'none';
    if (mainContainer) mainContainer.style.display = 'block';
}

function showLoadingError() {
    const errorMessage = document.getElementById('errorMessage');
    const loadingText = document.querySelector('.loading-container p');
    const spinner = document.querySelector('.spinner');
    
    if (loadingText) loadingText.style.display = 'none';
    if (spinner) spinner.style.display = 'none';
    if (errorMessage) errorMessage.style.display = 'block';
}

function showReportDetails(reportId) {
    // تنفيذ عرض التفاصيل
    console.log('Showing details for report:', reportId);
    // يمكنك تنفيذ modal للتفاصيل هنا
}