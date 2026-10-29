// whatsapp-handler.js - نظام مشاركة التقارير مع البيانات المفقودة
console.log('📱 تحميل نظام مشاركة الواتساب مع دعم البيانات المفقودة...');

// ============================================
// نظام توليد رسائل الواتساب مع البيانات المفقودة
// ============================================

class WhatsAppReportGenerator {
    constructor() {
        this.missingSymbol = '#';
    }

    // توليد رسالة التقرير
    generateReport() {
        const userData = JSON.parse(localStorage.getItem('currentUser') || '{}');
        const now = new Date();
        
        let message = `📊 *تقرير مناخي ساعي*\n`;
        message += `━━━━━━━━━━━━━━━━━━\n\n`;
        
        message += `*📋 المعلومات الأساسية*\n`;
        message += `🏢 المحطة: ${userData.station || 'غير محدد'}\n`;
        message += `👤 الراصد: ${userData.first_name || ''} ${userData.last_name || ''}\n`;
        message += `📅 التاريخ: ${now.toLocaleDateString('ar-SA')}\n`;
        message += `🕐 الوقت: ${now.toLocaleTimeString('ar-SA', { hour: '2-digit', minute: '2-digit' })}\n\n`;
        
        // قسم درجات الحرارة
        message += this.generateTemperatureSection();
        
        // قسم الرطوبة
        message += this.generateHumiditySection();
        
        // قسم الرياح
        message += this.generateWindSection();
        
        // قسم السحب
        message += this.generateCloudSection();
        
        // الملاحظات
        message += this.generateNotesSection();
        
        // إحصائيات البيانات المفقودة
        const missingCount = this.countMissingData();
        if (missingCount > 0) {
            message += `\n⚠️ *ملاحظة:* يحتوي التقرير على ${missingCount} حقل ببيانات مفقودة\n`;
        }
        
        message += `\n━━━━━━━━━━━━━━━━━━\n`;
        message += `📱 *نظام إدارة البيانات الجوية *`;
        
        return message;
    }

    // توليد قسم درجات الحرارة
    generateTemperatureSection() {
        const dryTemp = document.getElementById('dryTemp')?.value || '#';
        const wetTemp = document.getElementById('wetTemp')?.value || '#';
        const dewPoint = document.getElementById('dewPoint')?.value || '#';
        
        let section = `*🌡️ درجات الحرارة*\n`;
        
        section += `🌡️ الحرارة الجافة: ${this.formatValue(dryTemp, '°C')}\n`;
        section += `💧 الحرارة الرطبة: ${this.formatValue(wetTemp, '°C')}\n`;
        section += `🌫️ درجة الندى: ${this.formatValue(dewPoint, '°C')}\n`;
        
        // التحقق من العلاقة بين درجات الحرارة
        if (dryTemp !== '#' && wetTemp !== '#') {
            const dryNum = parseFloat(dryTemp);
            const wetNum = parseFloat(wetTemp);
            
            if (!isNaN(dryNum) && !isNaN(wetNum)) {
                if (dryNum < wetNum) {
                    section += `⚠️ علاقة غير صحيحة (جافة < رطبة)\n`;
                } else if (dryNum === wetNum) {
                    section += `✅ علاقة صحيحة (جافة = رطبة)\n`;
                } else {
                    section += `✅ علاقة صحيحة (جافة > رطبة)\n`;
                }
            }
        }
        
        section += `\n`;
        return section;
    }

    // توليد قسم الرطوبة
    generateHumiditySection() {
        const humidity = document.getElementById('relativeHumidity')?.value || '#';
        const vaporPressure = document.getElementById('vaporPressure')?.value || '#';
        
        let section = `*💦 الرطوبة والضغط*\n`;
        
        section += `💧 الرطوبة النسبية: ${this.formatValue(humidity, '%')}\n`;
        section += `📊 ضغط البخار: ${this.formatValue(vaporPressure, 'مليبار')}\n`;
        
        section += `\n`;
        return section;
    }

    // توليد قسم الرياح
    generateWindSection() {
        const windDir = document.getElementById('windDirection')?.value || '#';
        const windSpeed = document.getElementById('windSpeed')?.value || '#';
        const avgWindDir = document.getElementById('avgWindDirection')?.value || '#';
        const avgWindSpeed = document.getElementById('avgWindSpeed')?.value || '#';
        
        let section = `*💨 الرياح*\n`;
        
        section += `🧭 الاتجاه السطحي: ${this.formatValue(windDir, '°')}\n`;
        section += `💨 السرعة السطحية: ${this.formatValue(windSpeed, 'م/ثا')}\n`;
        section += `↔️ متوسط الاتجاه: ${this.formatValue(avgWindDir, '°')}\n`;
        section += `📈 متوسط السرعة: ${this.formatValue(avgWindSpeed, 'م/ثا')}\n`;
        
        section += `\n`;
        return section;
    }

    // توليد قسم السحب
    generateCloudSection() {
        const cloudCover = document.getElementById('totalCloudCover')?.value || '#';
        
        let section = `*☁️ السحب*\n`;
        
        section += `☁️ التغطية الكلية: ${this.formatValue(cloudCover, '/8')}\n`;
        
        section += `\n`;
        return section;
    }

    // توليد قسم الملاحظات
    generateNotesSection() {
        const notes = document.getElementById('observerNotes')?.value || '';
        
        if (!notes.trim()) {
            return '';
        }
        
        let section = `*📝 ملاحظات الراصد*\n`;
        section += `${notes}\n\n`;
        
        return section;
    }

    // تنسيق القيمة مع التعامل مع البيانات المفقودة
    formatValue(value, unit = '') {
        if (value === '#' || value === '' || value === null || value === undefined) {
            return `غير متوفر`;
        }
        
        return `${value} ${unit}`.trim();
    }

    // حساب عدد البيانات المفقودة
    countMissingData() {
        const fields = [
            'dryTemp', 'wetTemp', 'dewPoint', 'relativeHumidity',
            'vaporPressure', 'windDirection', 'windSpeed',
            'avgWindDirection', 'avgWindSpeed', 'totalCloudCover'
        ];
        
        let missingCount = 0;
        
        fields.forEach(fieldId => {
            const input = document.getElementById(fieldId);
            if (input && (input.value === '#' || input.value === '')) {
                missingCount++;
            }
        });
        
        return missingCount;
    }

    // إنشاء معاينة التقرير
    createPreview() {
        const report = this.generateReport();
        const missingCount = this.countMissingData();
        
        let previewHTML = `
            <div class="whatsapp-preview-container">
                <div class="preview-header">
                    <h5><i class="fab fa-whatsapp text-success me-2"></i>معاينة تقرير الواتساب</h5>
        `;
        
        if (missingCount > 0) {
            previewHTML += `
                <div class="alert alert-warning alert-sm mb-3">
                    <i class="fas fa-exclamation-triangle me-2"></i>
                    يحتوي التقرير على <strong>${missingCount}</strong> حقل ببيانات مفقودة
                </div>
            `;
        }
        
        previewHTML += `
                </div>
                <div class="preview-content">
                    <pre>${report}</pre>
                </div>
                <div class="preview-stats">
                    <small class="text-muted">
                        <i class="fas fa-info-circle me-1"></i>
                        عدد الأحرف: ${report.length} | البيانات المفقودة: ${missingCount}
                    </small>
                </div>
            </div>
        `;
        
        return previewHTML;
    }
}

// ============================================
// نظام معالجة مشاركة الواتساب
// ============================================

function handleWhatsAppShareWithMissingData() {
    console.log('📱 معالجة مشاركة واتساب مع بيانات مفقودة...');
    
    // التحقق من الحقول المطلوبة
    if (!validateRequiredFieldsForWhatsApp()) {
        showNotification('❌ يرجى ملء الحقول المطلوبة قبل المشاركة', 'error');
        return;
    }
    
    // تنسيق جميع الحقول
    if (window.smartFormatter) {
        window.smartFormatter.formatAllFields();
    }
    
    // إنشاء المعاينة
    const generator = new WhatsAppReportGenerator();
    const previewHTML = generator.createPreview();
    const reportText = generator.generateReport();
    
    // عرض المعاينة
    showWhatsAppPreview(previewHTML, reportText);
}

// التحقق من الحقول المطلوبة للواتساب
function validateRequiredFieldsForWhatsApp() {
    const requiredFields = ['localTime', 'dryTemp', 'wetTemp'];
    
    for (const fieldId of requiredFields) {
        const field = document.getElementById(fieldId);
        if (!field || !field.value.trim() || field.value === '#') {
            return false;
        }
    }
    
    return true;
}

// عرض معاينة الواتساب
function showWhatsAppPreview(previewHTML, reportText) {
    // إنشاء نافذة المعاينة
    const modalId = 'whatsappPreviewModal';
    let modal = document.getElementById(modalId);
    
    if (!modal) {
        modal = document.createElement('div');
        modal.id = modalId;
        modal.className = 'modal fade';
        modal.tabIndex = -1;
        modal.innerHTML = `
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header bg-success text-white">
                        <h5 class="modal-title">
                            <i class="fab fa-whatsapp me-2"></i>معاينة تقرير الواتساب
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body" id="whatsappPreviewContent">
                        ${previewHTML}
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-1"></i>إلغاء
                        </button>
                        <button type="button" class="btn btn-outline-success" id="copyWhatsAppTextBtn">
                            <i class="fas fa-copy me-1"></i>نسخ النص
                        </button>
                        <button type="button" class="btn btn-success" id="sendWhatsAppBtn">
                            <i class="fab fa-whatsapp me-1"></i>فتح واتساب
                        </button>
                    </div>
                </div>
            </div>
        `;
        
        document.body.appendChild(modal);
        
        // إعداد معالجات الأزرار
        const bsModal = new bootstrap.Modal(modal);
        
        modal.querySelector('#copyWhatsAppTextBtn').addEventListener('click', () => {
            copyToClipboard(reportText);
            showNotification('✅ تم نسخ نص التقرير إلى الحافظة', 'success');
        });
        
        modal.querySelector('#sendWhatsAppBtn').addEventListener('click', () => {
            sendToWhatsApp(reportText);
            bsModal.hide();
        });
    }
    
    // تحديث المحتوى
    const content = modal.querySelector('#whatsappPreviewContent');
    if (content) {
        content.innerHTML = previewHTML;
    }
    
    // إظهار النافذة
    const bsModal = new bootstrap.Modal(modal);
    bsModal.show();
    
    // تسجيل النشاط
    logUserActivity('whatsapp_preview_opened_with_missing_data', {
        missing_count: new WhatsAppReportGenerator().countMissingData()
    });
}

// إرسال إلى واتساب
function sendToWhatsApp(reportText) {
    const encodedText = encodeURIComponent(reportText);
    const whatsappURL = `https://wa.me/?text=${encodedText}`;
    
    window.open(whatsappURL, '_blank', 'noopener,noreferrer');
    
    showNotification('✅ تم فتح واتساب مع نص التقرير', 'success');
    
    // تسجيل المشاركة
    logUserActivity('whatsapp_shared_with_missing_data', {
        text_length: reportText.length,
        missing_count: new WhatsAppReportGenerator().countMissingData()
    });
}

// نسخ إلى الحافظة
function copyToClipboard(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text);
    } else {
        // طريقة بديلة
        const textarea = document.createElement('textarea');
        textarea.value = text;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
    }
}

// ============================================
// تهيئة نظام الواتساب
// ============================================

function initializeWhatsAppSystemWithMissingData() {
    console.log('🔧 تهيئة نظام واتساب مع دعم البيانات المفقودة...');
    
    // تحديث معالج زر الواتساب
    const whatsappBtn = document.getElementById('whatsappBtn');
    if (whatsappBtn) {
        whatsappBtn.removeEventListener('click', handleWhatsAppShare);
        whatsappBtn.addEventListener('click', handleWhatsAppShareWithMissingData);
        
        // تحديث تلميح الزر
        whatsappBtn.title = 'مشاركة التقرير عبر واتساب (يدعم البيانات المفقودة)';
        
        console.log('✅ تم تحديث معالج زر الواتساب');
    }
    
    // إضافة أنماط المعاينة
    addWhatsAppPreviewStyles();
}

// إضافة أنماط معاينة الواتساب
function addWhatsAppPreviewStyles() {
    const styleId = 'whatsapp-preview-styles';
    if (document.getElementById(styleId)) return;
    
    const styles = `
        /* أنماط معاينة الواتساب */
        .whatsapp-preview-container {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        
        .preview-header {
            border-bottom: 2px solid #25d366;
            padding-bottom: 10px;
            margin-bottom: 15px;
        }
        
        .preview-content {
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            padding: 15px;
            max-height: 400px;
            overflow-y: auto;
            font-family: monospace;
            font-size: 0.9rem;
            line-height: 1.5;
            white-space: pre-wrap;
            word-wrap: break-word;
        }
        
        .preview-content pre {
            margin: 0;
            white-space: pre-wrap;
            font-family: inherit;
        }
        
        .preview-stats {
            margin-top: 10px;
            padding-top: 10px;
            border-top: 1px solid #dee2e6;
            text-align: center;
        }
        
        .alert-sm {
            padding: 8px 12px;
            font-size: 0.85rem;
            margin-bottom: 10px;
        }
        
        /* تمييز البيانات المفقودة في المعاينة */
        .missing-data-highlight {
            background-color: #fff3cd;
            color: #856404;
            padding: 0 4px;
            border-radius: 3px;
            font-weight: bold;
        }
    `;
    
    const styleElement = document.createElement('style');
    styleElement.id = styleId;
    styleElement.textContent = styles;
    document.head.appendChild(styleElement);
}

// ============================================
// تشغيل النظام
// ============================================

document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 بدء تحميل نظام واتساب مع دعم البيانات المفقودة...');
    
    // الانتظار لتحميل بقية المكونات
    setTimeout(() => {
        initializeWhatsAppSystemWithMissingData();
        console.log('✅ تم تحميل نظام واتساب مع دعم البيانات المفقودة');
    }, 1000);
});

console.log('📱 تم تحميل نظام مشاركة الواتساب مع دعم البيانات المفقودة');