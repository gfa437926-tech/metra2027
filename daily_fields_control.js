// daily_fields_control.js - التحكم في إظهار وإخفاء الحقول

// تهيئة التحكم في الحقول
function initFieldsControl() {
    updateFieldsVisibility();
    
    // مراقبة تغيير نوع التقرير
    const reportTypeRadios = document.querySelectorAll('input[name="reportType"]');
    reportTypeRadios.forEach(radio => {
        radio.addEventListener('change', updateFieldsVisibility);
    });
}

// تحديث رؤية الحقول بناءً على نوع التقرير
function updateFieldsVisibility() {
    const selectedReportType = document.querySelector('input[name="reportType"]:checked');
    if (!selectedReportType) return;
    
    // الحقول التي تظهر فقط لتقرير 24 ساعة
    const sectionsToToggle = [
        'weatherPhenomenaSection',
        'evaporationSunshineSection',
        'windSection',
        'humiditySection'
    ];
    
    const is24hReport = selectedReportType.value === '24h';
    
    sectionsToToggle.forEach(sectionId => {
        const section = document.getElementById(sectionId);
        if (section) {
            section.style.display = is24hReport ? 'block' : 'none';
            
            // التحكم في الحقول المطلوبة
            const requiredFields = section.querySelectorAll('[required]');
            requiredFields.forEach(field => {
                if (is24hReport) {
                    field.disabled = false;
                    field.required = true;
                    
                    // إذا كانت القيمة #، نعيد تفعيل الحقل
                    if (field.value === '#') {
                        resetNoDataButton(field.id);
                    }
                } else {
                    field.disabled = true;
                    field.required = false;
                    if (field.value !== '#') {
                        field.value = '';
                    }
                }
            });
        }
    });
    
    // تحديث رسالة المعلومات
    updateReportTypeMessage(is24hReport);
    
    // تحديث حالة الأزرار "#"
    updateNoDataButtonsState(is24hReport);
}

// تحديث رسالة نوع التقرير
function updateReportTypeMessage(is24hReport) {
    const infoAlert = document.querySelector('.alert-info');
    if (!infoAlert) return;
    
    let message = '';
    if (is24hReport) {
        message = '<div class="text-success"><i class="fas fa-info-circle"></i> ملاحظة: في التقرير اليومي (24 ساعة)، يتم إدخال جميع البيانات الجوية.</div>';
    } else {
        message = '<div class="text-warning"><i class="fas fa-info-circle"></i> ملاحظة: في تقريري 06 و 18 عالمي، يتم إدخال درجات الحرارة وكميات الهطول فقط.</div>';
    }
    
    const existingMessage = infoAlert.querySelector('.report-type-message');
    if (existingMessage) {
        existingMessage.remove();
    }
    
    const messageDiv = document.createElement('div');
    messageDiv.className = 'report-type-message mt-2';
    messageDiv.innerHTML = message;
    infoAlert.appendChild(messageDiv);
}

// تحديث حالة أزرار "#" بناءً على رؤية الحقول
function updateNoDataButtonsState(is24hReport) {
    const sectionsToToggle = [
        'weatherPhenomenaSection',
        'evaporationSunshineSection',
        'windSection',
        'humiditySection'
    ];
    
    sectionsToToggle.forEach(sectionId => {
        const section = document.getElementById(sectionId);
        if (section) {
            const noDataButtons = section.querySelectorAll('.btn-no-data');
            noDataButtons.forEach(button => {
                if (is24hReport) {
                    button.disabled = false;
                    button.style.opacity = '1';
                } else {
                    button.disabled = true;
                    button.style.opacity = '0.5';
                    button.style.cursor = 'not-allowed';
                    
                    // إذا كان الزر مفعلاً، نعيده للحالة الأصلية
                    if (button.classList.contains('btn-success')) {
                        const targetId = button.getAttribute('data-target');
                        resetNoDataButton(targetId);
                    }
                }
            });
        }
    });
}

// إعادة تعيين زر "#"
function resetNoDataButton(fieldId) {
    const field = document.getElementById(fieldId);
    const button = document.querySelector(`.btn-no-data[data-target="${fieldId}"]`);
    
    if (field && button) {
        field.value = '';
        field.disabled = false;
        field.style.backgroundColor = '';
        field.style.color = '';
        
        button.classList.remove('btn-success');
        button.classList.add('btn-outline-info');
        button.innerHTML = '<i class="fas fa-hashtag"></i> لا تتوفر معلومات';
        button.disabled = false;
        button.style.opacity = '1';
        button.style.cursor = 'pointer';
    }
}

// جعل الدوال متاحة globally
window.initFieldsControl = initFieldsControl;
window.updateFieldsVisibility = updateFieldsVisibility;
window.resetNoDataButton = resetNoDataButton;

// التهيئة عند تحميل الصفحة
document.addEventListener('DOMContentLoaded', function() {
    initFieldsControl();
});