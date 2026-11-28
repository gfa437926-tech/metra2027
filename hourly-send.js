// hourly-send.js - مع دعم # وإظهار حقول الضغط عند 00 أيضاً
console.log('🔄 تحميل hourly-send.js (نسخة تدعم # وتظهر حقول الضغط عند 00)');

const hourlySend = {
    init() {
        this.setupTimeDependentFields();
        this.setupEventListeners();
        console.log('✅ نظام الإرسال الساعي جاهز');
    },

    setupTimeDependentFields() {
        const utcSelect = document.getElementById('utcTime');
        if (!utcSelect) return;
        utcSelect.addEventListener('change', () => this.updateTimeDependentFields(utcSelect.value));
        if (utcSelect.value) this.updateTimeDependentFields(utcSelect.value);
    },

    updateTimeDependentFields(utcHour) {
        if (!utcHour) return;
        const hour = utcHour.padStart(2, '0');
        const showPrecip = ['00', '06', '12', '18'].includes(hour);
        // ✅ التعديل: إضافة '00' إلى الساعات التي تظهر فيها حقول ميل الضغط
        const showPressure = ['00', '03', '06', '09', '12', '15', '18', '21'].includes(hour);
        this.toggleField('precipitationFields', showPrecip);
        this.toggleField('pressureSlopeFields', showPressure);
        this.updateFieldRequirements(showPrecip, showPressure);
    },

    toggleField(id, show) {
        const el = document.getElementById(id);
        if (!el) return;
        if (show) {
            el.classList.add('active');
        } else {
            el.classList.remove('active');
            el.querySelectorAll('input').forEach(inp => {
                inp.value = '';
                inp.classList.remove('is-valid', 'is-invalid');
                const err = document.getElementById(inp.id + 'Error');
                if (err) err.style.display = 'none';
                const suc = document.getElementById(inp.id + 'Success');
                if (suc) suc.style.display = 'none';
            });
        }
    },

    updateFieldRequirements(showPrecip, showPressure) {
        const precip = document.getElementById('precipitationAmount');
        if (precip) precip.required = showPrecip;
        const slope = document.getElementById('pressureSlope');
        const shape = document.getElementById('pressureShape');
        if (slope) slope.required = showPressure;
        if (shape) shape.required = showPressure;
    },

    setupEventListeners() {
        document.querySelectorAll('.sign-toggle').forEach(btn => {
            btn.addEventListener('click', () => {
                const target = btn.getAttribute('data-target');
                const sign = btn.getAttribute('data-sign');
                this.applySignToField(target, sign);
            });
        });
        const agree = document.getElementById('responsibilityAgreement');
        if (agree) agree.addEventListener('change', () => agree.classList.toggle('is-invalid', !agree.checked));
    },

    applySignToField(targetId, sign) {
        const field = document.getElementById(targetId);
        if (!field) return;
        let val = field.value.trim();
        if (val === '#') return;
        val = val.replace(/^[+\-]/, '');
        field.value = sign === '-' ? '-' + val : '+' + val;
        if (window.enhancedValidation) window.enhancedValidation.validateField(field);
        this.updateSignButtons(targetId, sign);
    },

    updateSignButtons(targetId, activeSign) {
        document.querySelectorAll(`.sign-toggle[data-target="${targetId}"]`).forEach(btn => {
            if (btn.getAttribute('data-sign') === activeSign) btn.classList.add('active');
            else btn.classList.remove('active');
        });
    },

    validateForm() {
        console.log('🔍 التحقق من النموذج (hourly-send) - يدعم #');
        let valid = true;
        const required = ['utcTime', 'dryTemp', 'wetTemp', 'stationPressure', 'seaLevelPressure', 'windDirection', 'windSpeed', 'visibility', 'totalCloudCover', 'relativeHumidity', 'dewPoint'];
        for (const id of required) {
            const f = document.getElementById(id);
            if (f && f.required) {
                const v = f.value?.trim() || '';
                if (v === '') {
                    valid = false;
                    f.classList.add('is-invalid');
                } else {
                    f.classList.remove('is-invalid');
                    f.classList.add('is-valid');
                }
            }
        }
        const utc = document.getElementById('utcTime');
        if (utc && utc.value && ['00', '06', '12', '18'].includes(utc.value.padStart(2, '0'))) {
            const precip = document.getElementById('precipitationAmount');
            if (precip && precip.required) {
                const v = precip.value?.trim() || '';
                if (v === '') {
                    valid = false;
                    precip.classList.add('is-invalid');
                }
            }
        }
        // التحقق من ميل الضغط وشكله في الساعات المحددة (بما فيها 00)
        if (utc && utc.value && ['00', '03', '06', '09', '12', '15', '18', '21'].includes(utc.value.padStart(2, '0'))) {
            const slope = document.getElementById('pressureSlope');
            const shape = document.getElementById('pressureShape');
            if (slope && slope.required) {
                const v = slope.value?.trim() || '';
                if (v === '') {
                    valid = false;
                    slope.classList.add('is-invalid');
                }
            }
            if (shape && shape.required) {
                const v = shape.value?.trim() || '';
                if (v === '') {
                    valid = false;
                    shape.classList.add('is-invalid');
                }
            }
        }
        const agree = document.getElementById('responsibilityAgreement');
        if (agree && !agree.checked) {
            valid = false;
            agree.classList.add('is-invalid');
        }
        if (!valid && window.showNotification) window.showNotification('يرجى تصحيح الحقول الحمراء (الرمز # مسموح به)', 'error');
        return valid;
    }
};

window.hourlySend = hourlySend;
window.updateTimeDependentFields = hourlySend.updateTimeDependentFields.bind(hourlySend);

document.addEventListener('DOMContentLoaded', () => {
    if (window.hourlySend) window.hourlySend.init();
});