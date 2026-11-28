// auto-format-helpers.js - مساعدات إضافية للتنسيق التلقائي (محدث - بدون توقيت محلي)
console.log('🔧 تحميل مساعدات التنسيق التلقائي (UTC فقط)...');

// تعريف تنسيقات الحقول العالمية (محدثة)
const FIELD_FORMATS = window.FIELD_FORMATS || {
    temperature: {
        pattern: /^-?\d{1,2}\.\d$/,
        min: -20.0,
        max: 60.0,
        decimalPlaces: 1,
        format: (value) => {
            const num = parseFloat(value);
            if (isNaN(num)) return '';
            return num.toFixed(1);
        }
    },
    humidity: {
        pattern: /^\d{3}$/,
        min: 0,
        max: 100,
        format: (value) => {
            const num = parseInt(value);
            if (isNaN(num)) return '';
            return Math.max(0, Math.min(100, num)).toString().padStart(3, '0');
        }
    },
    vaporPressure: {
        pattern: /^-?\d{1,2}\.\d$/,
        min: -50.0,
        max: 50.0,
        decimalPlaces: 1,
        format: (value) => {
            const num = parseFloat(value);
            if (isNaN(num)) return '';
            return num.toFixed(1);
        }
    },
    direction: {
        pattern: /^\d{2}$/,
        min: 0,
        max: 36,
        format: (value) => {
            const num = parseInt(value);
            if (isNaN(num)) return '';
            return Math.max(0, Math.min(36, num)).toString().padStart(2, '0');
        }
    },
    windSpeed: {
        pattern: /^\d{2}$/,
        min: 0,
        max: 99,
        format: (value) => {
            const num = parseInt(value);
            if (isNaN(num)) return '';
            return Math.max(0, Math.min(99, num)).toString().padStart(2, '0');
        }
    },
    cloudCover: {
        pattern: /^[0-9]$/,
        min: 0,
        max: 9,
        format: (value) => {
            const num = parseInt(value);
            if (isNaN(num)) return '';
            return Math.max(0, Math.min(9, num)).toString();
        }
    },
    utcTime: {
        pattern: /^([01]\d|2[0-3]):00$|^#$/,
        format: (value) => {
            if (value === '#') return '#';
            
            // التحقق من تنسيق UTC
            const pattern = /^([01]\d|2[0-3]):00$/;
            if (!pattern.test(value)) {
                return '00:00'; // القيمة الافتراضية
            }
            
            return value;
        }
    }
};

// دالة لتنسيق جميع الحقول دفعة واحدة
function formatAllFields() {
    console.log('🔄 تنسيق جميع الحقول (UTC فقط)...');
    
    const fields = [
        'dryTemp', 'wetTemp', 'dewPoint', 'vaporPressure',
        'relativeHumidity', 'windDirection', 'windSpeed',
        'avgWindDirection', 'avgWindSpeed', 'totalCloudCover',
        'utcTime'
    ];
    
    let formattedCount = 0;
    
    fields.forEach(fieldId => {
        const input = document.getElementById(fieldId);
        if (input && input.value) {
            const original = input.value;
            const formatted = autoFormatField(fieldId, original);
            
            if (formatted !== original) {
                input.value = formatted;
                updateSignIndicator(fieldId);
                formattedCount++;
                
                // إضافة تأثير مرئي
                input.classList.add('field-auto-formatted');
                setTimeout(() => {
                    input.classList.remove('field-auto-formatted');
                }, 1000);
            }
        }
    });
    
    if (formattedCount > 0) {
        showNotification(`✅ تم تنسيق ${formattedCount} حقول تلقائياً (UTC فقط)`, 'success');
    }
    
    return formattedCount;
}

// دالة لفحص جميع الحقول
function validateAllFields() {
    console.log('🔍 فحص جميع الحقول (UTC فقط)...');
    
    const fields = [
        'utcTime', 'dryTemp', 'wetTemp', 'dewPoint', 'vaporPressure',
        'relativeHumidity', 'windDirection', 'windSpeed',
        'avgWindDirection', 'avgWindSpeed', 'totalCloudCover'
    ];
    
    let validCount = 0;
    let invalidFields = [];
    
    fields.forEach(fieldId => {
        const input = document.getElementById(fieldId);
        if (input && input.value) {
            const formatType = getFormatType(fieldId);
            if (formatType && FIELD_FORMATS[formatType]) {
                const format = FIELD_FORMATS[formatType];
                const value = input.value;
                
                if (format.pattern.test(value)) {
                    validCount++;
                    input.classList.remove('has-error');
                    input.classList.add('has-success');
                } else {
                    invalidFields.push({
                        field: fieldId,
                        value: value,
                        expected: getFormatExample(formatType)
                    });
                    input.classList.add('has-error');
                    input.classList.remove('has-success');
                }
            }
        }
    });
    
    console.log(`✅ الحقول الصحيحة: ${validCount}/${fields.length}`);
    
    if (invalidFields.length > 0) {
        console.warn('❌ الحقول غير الصحيحة:', invalidFields);
        
        // إظهار رسالة للمستخدم
        if (invalidFields.length === 1) {
            showNotification(`⚠️ هناك حقل يحتاج تصحيح: ${getFieldName(invalidFields[0].field)}`, 'warning');
        } else if (invalidFields.length > 1) {
            showNotification(`⚠️ هناك ${invalidFields.length} حقول تحتاج تصحيح`, 'warning');
        }
        
        // إبراز الحقول غير الصحيحة
        invalidFields.forEach(item => {
            const input = document.getElementById(item.field);
            if (input) {
                input.classList.add('field-error-highlight');
                setTimeout(() => {
                    input.classList.remove('field-error-highlight');
                }, 3000);
            }
        });
    } else {
        showNotification(`✅ جميع الحقول ${validCount}/${fields.length} صحيحة التنسيق (UTC فقط)`, 'success');
    }
    
    return invalidFields.length === 0;
}

// دالة للحصول على مثال التنسيق
function getFormatExample(formatType) {
    const examples = {
        'temperature': 'مثال: 25.5 أو -15.2',
        'humidity': 'مثال: 075 أو 100',
        'vaporPressure': 'مثال: 18.5 أو -5.2',
        'direction': 'مثال: 15 أو 36',
        'windSpeed': 'مثال: 12 أو 99',
        'cloudCover': 'مثال: 3 أو 9',
        'utcTime': 'مثال: 14:00 أو #'
    };
    
    return examples[formatType] || 'تنسيق غير معروف';
}

// دالة لتعيين تنسيق حقل معين
function setFieldFormat(fieldId, value) {
    const input = document.getElementById(fieldId);
    if (!input) return false;
    
    const formattedValue = autoFormatField(fieldId, value);
    if (formattedValue !== value) {
        input.value = formattedValue;
        updateSignIndicator(fieldId);
        
        // تشغيل أحداث التحقق
        input.dispatchEvent(new Event('change'));
        input.dispatchEvent(new Event('blur'));
        
        return true;
    }
    
    return false;
}

// دالة لعرض حالة جميع الحقول
function showFieldsStatus() {
    const fields = [
        'utcTime', 'dryTemp', 'wetTemp', 'dewPoint', 'vaporPressure',
        'relativeHumidity', 'windDirection', 'windSpeed',
        'avgWindDirection', 'avgWindSpeed', 'totalCloudCover'
    ];
    
    const status = {};
    
    fields.forEach(fieldId => {
        const input = document.getElementById(fieldId);
        status[fieldId] = {
            hasValue: !!(input && input.value),
            isFormatted: false,
            value: input ? input.value : null,
            formatType: getFormatType(fieldId)
        };
        
        if (input && input.value) {
            const formatType = getFormatType(fieldId);
            if (formatType && FIELD_FORMATS[formatType]) {
                status[fieldId].isFormatted = FIELD_FORMATS[formatType].pattern.test(input.value);
            }
        }
    });
    
    console.table(status);
    
    // عرض النتائج في واجهة المستخدم
    displayFieldsStatus(status);
    
    return status;
}

// عرض حالة الحقول في واجهة المستخدم
function displayFieldsStatus(status) {
    let statusHTML = '<div class="fields-status-report"><h6>📊 تقرير حالة الحقول (UTC فقط)</h6><ul class="list-group">';
    
    Object.keys(status).forEach(fieldId => {
        const field = status[fieldId];
        const fieldName = getFieldName(fieldId);
        
        statusHTML += `
            <li class="list-group-item d-flex justify-content-between align-items-center">
                <div>
                    <span class="badge bg-${field.hasValue ? 'info' : 'secondary'} me-2">
                        ${field.hasValue ? '✏️' : '🔲'}
                    </span>
                    ${fieldName}
                </div>
                <div>
                    <span class="badge bg-${field.isFormatted ? 'success' : field.hasValue ? 'warning' : 'secondary'} me-1">
                        ${field.value || 'فارغ'}
                    </span>
                    <span class="badge bg-${field.isFormatted ? 'success' : 'light'} text-dark">
                        ${field.isFormatted ? '✓' : '✗'}
                    </span>
                </div>
            </li>
        `;
    });
    
    statusHTML += '</ul></div>';
    
    // إنشاء نافذة عائمة لعرض الحالة
    const statusModal = document.createElement('div');
    statusModal.id = 'fieldsStatusModal';
    statusModal.className = 'fields-status-modal';
    statusModal.innerHTML = `
        <div class="fields-status-content">
            <div class="fields-status-header">
                <h5>📊 حالة الحقول (UTC فقط)</h5>
                <button class="btn-close" id="closeStatusModal"></button>
            </div>
            <div class="fields-status-body">
                ${statusHTML}
            </div>
            <div class="fields-status-footer">
                <button class="btn btn-sm btn-primary" id="formatAllFromStatus">🔄 تنسيق الكل</button>
                <button class="btn btn-sm btn-secondary" id="closeStatusBtn">إغلاق</button>
            </div>
        </div>
    `;
    
    // إضافة الأنماط إذا لم تكن موجودة
    addStatusModalStyles();
    
    // إضافة إلى الصفحة
    document.body.appendChild(statusModal);
    
    // إضافة مستمعي الأحداث
    document.getElementById('closeStatusModal').addEventListener('click', () => {
        statusModal.remove();
    });
    
    document.getElementById('closeStatusBtn').addEventListener('click', () => {
        statusModal.remove();
    });
    
    document.getElementById('formatAllFromStatus').addEventListener('click', () => {
        formatAllFields();
        statusModal.remove();
    });
    
    // إغلاق عند النقر خارج الصندوق
    statusModal.addEventListener('click', (e) => {
        if (e.target === statusModal) {
            statusModal.remove();
        }
    });
}

// دالة للحصول على اسم الحقل بالعربية (محدثة)
function getFieldName(fieldId) {
    const fieldNames = {
        'utcTime': 'التوقيت العالمي (UTC)',
        'dryTemp': 'الحرارة الجافة',
        'wetTemp': 'الحرارة الرطبة',
        'dewPoint': 'درجة الندى',
        'vaporPressure': 'ضغط البخار',
        'relativeHumidity': 'الرطوبة النسبية',
        'windDirection': 'اتجاه الرياح',
        'windSpeed': 'سرعة الرياح',
        'avgWindDirection': 'متوسط الاتجاه',
        'avgWindSpeed': 'متوسط السرعة',
        'totalCloudCover': 'التغطية السحابية'
    };
    
    return fieldNames[fieldId] || fieldId;
}

// دالة لتحديد نوع التنسيق (محدثة)
function getFormatType(fieldId) {
    if (fieldId === 'utcTime') {
        return 'utcTime';
    } else if (fieldId.includes('Temp') || fieldId.includes('dewPoint')) {
        return 'temperature';
    } else if (fieldId.includes('Humidity')) {
        return 'humidity';
    } else if (fieldId.includes('vaporPressure')) {
        return 'vaporPressure';
    } else if (fieldId.includes('Direction')) {
        return 'direction';
    } else if (fieldId.includes('Speed')) {
        return 'windSpeed';
    } else if (fieldId.includes('Cloud')) {
        return 'cloudCover';
    }
    return null;
}

// دالة التنسيق التلقائي الأساسية (محدثة)
function autoFormatField(fieldId, value) {
    if (!value || value.trim() === '') return value;
    
    const formatType = getFormatType(fieldId);
    if (!formatType || !FIELD_FORMATS[formatType]) return value;
    
    const format = FIELD_FORMATS[formatType];
    
    try {
        if (formatType === 'utcTime') {
            // معالجة وقت UTC
            if (value === '#') return '#';
            
            // التحقق من تنسيق الساعة
            const hourMatch = value.match(/(\d{1,2})/);
            if (hourMatch) {
                let hour = parseInt(hourMatch[1]);
                // تحديد النطاق 0-23
                hour = Math.max(0, Math.min(23, hour));
                return `${hour.toString().padStart(2, '0')}:00`;
            }
            return value;
        } else if (formatType === 'temperature' || formatType === 'vaporPressure') {
            // الحقول العشرية
            const num = parseFloat(value);
            if (isNaN(num)) return value;
            
            // التحقق من النطاق
            if (num < format.min || num > format.max) {
                return value;
            }
            
            return format.format(value);
        } else {
            // الحقول الصحيحة
            const num = parseInt(value);
            if (isNaN(num)) return value;
            
            // التحقق من النطاق
            if (num < format.min || num > format.max) {
                return value;
            }
            
            return format.format(value);
        }
    } catch (error) {
        console.error(`خطأ في تنسيق الحقل ${fieldId}:`, error);
        return value;
    }
}

// دالة لتحديث إشارة السالب/الموجب
function updateSignIndicator(fieldId) {
    const input = document.getElementById(fieldId);
    const signElement = document.getElementById(fieldId + 'Sign');
    
    if (!input || !signElement) return;
    
    // لا تعمل مع حقول UTC أو غير الرقمية
    if (fieldId === 'utcTime' || fieldId.includes('Time')) return;
    
    const value = parseFloat(input.value);
    
    if (isNaN(value)) {
        signElement.textContent = '+';
        input.parentElement.classList.remove('has-positive', 'has-negative');
    } else if (value < 0) {
        signElement.textContent = '-';
        input.parentElement.classList.add('has-negative');
        input.parentElement.classList.remove('has-positive');
    } else {
        signElement.textContent = '+';
        input.parentElement.classList.add('has-positive');
        input.parentElement.classList.remove('has-negative');
    }
}

// دالة لإظهار الإشعارات
function showNotification(message, type = 'success') {
    // البحث عن حاوية الإشعارات أو إنشاؤها
    let notificationContainer = document.getElementById('notificationContainer');
    if (!notificationContainer) {
        notificationContainer = document.createElement('div');
        notificationContainer.id = 'notificationContainer';
        notificationContainer.style.cssText = `
            position: fixed;
            top: 20px;
            left: 50%;
            transform: translateX(-50%);
            z-index: 1100;
            width: 90%;
            max-width: 500px;
        `;
        document.body.appendChild(notificationContainer);
    }
    
    // إنشاء الإشعار
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    notificationContainer.appendChild(notification);
    
    // إزالة تلقائية بعد 5 ثواني
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, 5000);
    
    // تسجيل في الكونسول
    console.log(`📢 ${type}: ${message}`);
}

// إضافة أنماط نافذة الحالة
function addStatusModalStyles() {
    if (document.getElementById('fieldsStatusStyles')) return;
    
    const styles = `
        .fields-status-modal {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.5);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 9999;
            animation: fadeIn 0.3s ease;
        }
        
        .fields-status-content {
            background: white;
            border-radius: 10px;
            width: 90%;
            max-width: 600px;
            max-height: 80vh;
            overflow: hidden;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
            animation: slideUp 0.3s ease;
        }
        
        .fields-status-header {
            background: linear-gradient(135deg, #3498db 0%, #2980b9 100%);
            color: white;
            padding: 15px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .fields-status-header h5 {
            margin: 0;
            font-size: 1.2rem;
        }
        
        .fields-status-body {
            padding: 20px;
            max-height: 60vh;
            overflow-y: auto;
        }
        
        .fields-status-footer {
            padding: 15px 20px;
            background: #f8f9fa;
            border-top: 1px solid #dee2e6;
            display: flex;
            gap: 10px;
            justify-content: flex-end;
        }
        
        .fields-status-report .list-group-item {
            padding: 10px 15px;
            border-left: none;
            border-right: none;
        }
        
        @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
        }
        
        @keyframes slideUp {
            from { transform: translateY(50px); opacity: 0; }
            to { transform: translateY(0); opacity: 1; }
        }
        
        /* تأثيرات إضافية */
        .field-auto-formatted {
            animation: pulse-success 0.8s ease;
        }
        
        .field-error-highlight {
            animation: shake 0.5s ease;
            border-color: #dc3545 !important;
        }
        
        @keyframes pulse-success {
            0% { box-shadow: 0 0 0 0 rgba(40, 167, 69, 0.7); }
            70% { box-shadow: 0 0 0 10px rgba(40, 167, 69, 0); }
            100% { box-shadow: 0 0 0 0 rgba(40, 167, 69, 0); }
        }
        
        @keyframes shake {
            0%, 100% { transform: translateX(0); }
            25% { transform: translateX(-5px); }
            75% { transform: translateX(5px); }
        }
    `;
    
    const styleElement = document.createElement('style');
    styleElement.id = 'fieldsStatusStyles';
    styleElement.textContent = styles;
    document.head.appendChild(styleElement);
}

// إضافة أزرار التحكم (للأغراض التطويرية)
function addControlButtons() {
    // التحقق مما إذا كانت اللوحة موجودة بالفعل
    if (document.getElementById('formatControlPanel')) {
        console.log('⚠️ لوحة التحكم موجودة بالفعل');
        return;
    }
    
    console.log('🛠️ إنشاء لوحة تحكم التنسيق (UTC فقط)...');
    
    const controlPanel = document.createElement('div');
    controlPanel.id = 'formatControlPanel';
    controlPanel.style.cssText = `
        position: fixed;
        bottom: 60px;
        right: 20px;
        z-index: 9998;
        background: white;
        padding: 10px;
        border-radius: 8px;
        box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        display: none;
        border: 1px solid #dee2e6;
        min-width: 200px;
    `;
    
    controlPanel.innerHTML = `
        <h6 class="mb-2 d-flex align-items-center">
            <i class="fas fa-tools me-2"></i>أدوات التنسيق (UTC)
        </h6>
        <button id="formatAllBtn" class="btn btn-sm btn-success mb-1 w-100 d-flex align-items-center justify-content-center">
            <i class="fas fa-sync-alt me-2"></i>تنسيق الكل
        </button>
        <button id="validateAllBtn" class="btn btn-sm btn-info mb-1 w-100 d-flex align-items-center justify-content-center">
            <i class="fas fa-check-circle me-2"></i>فحص الكل
        </button>
        <button id="showStatusBtn" class="btn btn-sm btn-secondary mb-1 w-100 d-flex align-items-center justify-content-center">
            <i class="fas fa-chart-bar me-2"></i>عرض الحالة
        </button>
        <hr class="my-1">
        <button id="closeControlPanel" class="btn btn-sm btn-outline-danger w-100">
            <i class="fas fa-times me-1"></i>إغلاق
        </button>
    `;
    
    document.body.appendChild(controlPanel);
    
    // إضافة زر التحكم الرئيسي
    const controlBtn = document.createElement('button');
    controlBtn.id = 'controlPanelToggle';
    controlBtn.className = 'btn btn-sm btn-outline-primary position-fixed';
    controlBtn.style.cssText = `
        bottom: 20px;
        right: 20px;
        z-index: 9999;
        padding: 8px 12px;
        border-radius: 50%;
        width: 50px;
        height: 50px;
        display: flex;
        align-items: center;
        justify-content: center;
        box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    `;
    controlBtn.innerHTML = '<i class="fas fa-tools"></i>';
    controlBtn.title = 'أدوات التنسيق التلقائي (UTC)';
    
    controlBtn.addEventListener('click', function() {
        const panel = document.getElementById('formatControlPanel');
        if (panel.style.display === 'none' || panel.style.display === '') {
            panel.style.display = 'block';
            this.innerHTML = '<i class="fas fa-times"></i>';
        } else {
            panel.style.display = 'none';
            this.innerHTML = '<i class="fas fa-tools"></i>';
        }
    });
    
    document.body.appendChild(controlBtn);
    
    // إعداد معالجات الأزرار
    document.getElementById('formatAllBtn').addEventListener('click', () => {
        formatAllFields();
        const panel = document.getElementById('formatControlPanel');
        panel.style.display = 'none';
        controlBtn.innerHTML = '<i class="fas fa-tools"></i>';
    });
    
    document.getElementById('validateAllBtn').addEventListener('click', () => {
        validateAllFields();
    });
    
    document.getElementById('showStatusBtn').addEventListener('click', () => {
        showFieldsStatus();
        const panel = document.getElementById('formatControlPanel');
        panel.style.display = 'none';
        controlBtn.innerHTML = '<i class="fas fa-tools"></i>';
    });
    
    document.getElementById('closeControlPanel').addEventListener('click', function() {
        document.getElementById('formatControlPanel').style.display = 'none';
        controlBtn.innerHTML = '<i class="fas fa-tools"></i>';
    });
    
    // إخفاء اللوحة عند النقر خارجها
    document.addEventListener('click', function(event) {
        const panel = document.getElementById('formatControlPanel');
        const toggle = document.getElementById('controlPanelToggle');
        
        if (panel && panel.style.display === 'block' && 
            !panel.contains(event.target) && 
            !toggle.contains(event.target)) {
            panel.style.display = 'none';
            toggle.innerHTML = '<i class="fas fa-tools"></i>';
        }
    });
    
    console.log('✅ تم إنشاء لوحة تحكم التنسيق (UTC فقط)');
}

// تهيئة المساعدات عند تحميل الصفحة
document.addEventListener('DOMContentLoaded', function() {
    console.log('🔧 تهيئة مساعدات التنسيق التلقائي (UTC فقط)...');
    
    // الانتظار حتى يتم تهيئة النظام الرئيسي
    setTimeout(() => {
        // إضافة أزرار التحكم (للتطوير فقط)
        if (window.location.href.includes('localhost') || 
            window.location.href.includes('127.0.0.1') ||
            window.location.href.includes('dev') ||
            window.location.href.includes('test')) {
            addControlButtons();
            console.log('🛠️ تم إضافة أدوات التطوير (UTC فقط)');
        }
        
        console.log('✅ تم تحميل مساعدات التنسيق التلقائي (UTC فقط)');
    }, 1500);
});

// جعل الدوال متاحة عالمياً
window.autoFormatField = autoFormatField;
window.formatAllFields = formatAllFields;
window.validateAllFields = validateAllFields;
window.showFieldsStatus = showFieldsStatus;
window.setFieldFormat = setFieldFormat;
window.updateSignIndicator = updateSignIndicator;
window.FIELD_FORMATS = FIELD_FORMATS;

console.log('🔧 تم تحميل مساعدات التنسيق التلقائي (UTC فقط)');