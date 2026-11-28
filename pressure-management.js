// pressure-management.js - إدارة حقول الضغط بناءً على التوقيت
console.log('🔄 تحميل نظام إدارة حقول الضغط...');

class PressureManager {
    constructor() {
        this.init();
    }

    init() {
        this.setupPressureFields();
        this.setupTimeListeners();
        console.log('✅ نظام إدارة حقول الضغط جاهز');
    }

    setupPressureFields() {
        // إخفاء حقول الضغط والهطول في البداية
        this.togglePressureFields(false);
    }

    setupTimeListeners() {
        const localTime = document.getElementById('localTime');
        if (localTime) {
            localTime.addEventListener('change', () => {
                this.updatePressureVisibility();
            });
        }
    }

    updatePressureVisibility() {
        const localTime = document.getElementById('localTime');
        
        if (!localTime.value) return;
        
        const localHour = parseInt(localTime.value);
        const utcHour = (localHour - 3 + 24) % 24; // UTC+3 لسوريا
        
        // تحديث حقل UTC
        const utcTime = document.getElementById('utcTime');
        if (utcTime) {
            utcTime.value = utcHour.toString().padStart(2, '0');
        }
        
        // إدارة حقول شكل الضغط وميل الضغط والهطول
        this.managePressureFields(utcHour);
        
        // إدارة حقل الطقس الغابر
        this.managePastWeatherField(utcHour);
    }

    managePressureFields(utcHour) {
        // ساعات ظهور شكل الضغط وميله: 03,0, 06, 09, 12, 15, 18, 21 UTC
        const pressureVisibleHours = [3, 6, 9, 12, 15, 18, 21,0];
        const isVisible = pressureVisibleHours.includes(utcHour);
        
        this.togglePressureFields(isVisible);
        
        if (!isVisible) {
            this.clearPressureFields();
        }
    }

    managePastWeatherField(utcHour) {
        // ساعات ظهور الطقس الغابر: 00, 03, 06, 09, 12, 15, 18, 21 UTC
        const pastWeatherVisibleHours = [0, 3, 6, 9, 12, 15, 18, 21];
        const isVisible = pastWeatherVisibleHours.includes(utcHour);
        
        this.togglePastWeather(isVisible);
        
        if (!isVisible) {
            this.clearPastWeather();
        }
    }

    togglePressureFields(show) {
        const fields = ['pressurePattern', 'pressureTendency', 'precipitation'];
        const section = document.getElementById('pressureFieldsSection');
        
        fields.forEach(fieldId => {
            const field = document.getElementById(fieldId);
            if (field) {
                field.disabled = !show;
                field.required = show;
                
                const cardField = field.closest('.card-field');
                if (cardField) {
                    cardField.style.display = show ? 'block' : 'none';
                    cardField.classList.toggle('field-disabled', !show);
                }
            }
        });
        
        if (section) {
            section.style.display = show ? 'block' : 'none';
        }
    }

    togglePastWeather(show) {
        const field = document.getElementById('pastWeather');
        if (field) {
            field.disabled = !show;
            field.required = show;
            
            const cardField = field.closest('.card-field');
            if (cardField) {
                cardField.style.display = show ? 'block' : 'none';
                cardField.classList.toggle('field-disabled', !show);
            }
        }
    }

    clearPressureFields() {
        ['pressurePattern', 'pressureTendency', 'precipitation'].forEach(fieldId => {
            const field = document.getElementById(fieldId);
            if (field) {
                field.value = '';
                field.classList.remove('is-valid', 'is-invalid');
            }
        });
    }

    clearPastWeather() {
        const field = document.getElementById('pastWeather');
        if (field) {
            field.value = '';
            field.classList.remove('is-valid', 'is-invalid');
        }
    }
}

// تهيئة النظام
document.addEventListener('DOMContentLoaded', function() {
    window.pressureManager = new PressureManager();
});