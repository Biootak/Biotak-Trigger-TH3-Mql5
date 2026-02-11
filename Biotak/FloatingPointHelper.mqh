#ifndef FLOATING_POINT_HELPER_MQH
#define FLOATING_POINT_HELPER_MQH

// Epsilon Constants
#define EPSILON_BASE 1e-10
#define EPSILON_PERCENTAGE 1e-10
#define EPSILON_RATIO 1e-8
#define EPSILON_ANGLE 1e-6
#define EPSILON_GENERAL 1e-9
#define EPSILON_PRICE_SCALE 1e-8
#define EPSILON_PRICE EPSILON_BASE

double GetDynamicEpsilonForPrice(double price) {
        double epsilon = MathAbs(price) * EPSILON_PRICE_SCALE;
    if(epsilon < EPSILON_BASE) epsilon = EPSILON_BASE;
    return epsilon;
}

// Comparison Functions
bool IsZero(double value, double epsilon = EPSILON_GENERAL) {
        return MathAbs(value) < epsilon;
}
    bool AreEqual(double value1, double value2, double epsilon = EPSILON_GENERAL) {
        return MathAbs(value1 - value2) < epsilon;
}
    bool IsGreater(double value1, double value2, double epsilon = EPSILON_GENERAL) {
    return (value1 - value2) > epsilon;
}
    bool IsLess(double value1, double value2, double epsilon = EPSILON_GENERAL) {
    return (value2 - value1) > epsilon;
}
    bool IsGreaterOrEqual(double value1, double value2, double epsilon = EPSILON_GENERAL) {
    return (value1 - value2) > -epsilon;
}
    bool IsLessOrEqual(double value1, double value2, double epsilon = EPSILON_GENERAL) {
    return (value2 - value1) > -epsilon;
}

// Safe Math
double SafeDivide(double numerator, double denominator, double defaultValue = 0.0, double epsilon = EPSILON_GENERAL) {
        if(IsZero(denominator, epsilon)) return defaultValue;
    return numerator / denominator;
}
    double SafeSqrt(double value, double defaultValue = 0.0, double epsilon = EPSILON_GENERAL) {
        if(value < -epsilon) return defaultValue;
    if(value < 0) value = 0;
    return MathSqrt(value);
}
    double ClampValue(double value, double minVal, double maxVal) {
        if(value < minVal) return minVal;
    if(value > maxVal) return maxVal;
    return value;
}
    double NormalizePrice(double price) {
        return NormalizeDouble(price, Digits);
}
    bool IsValidPrice(double price, double epsilon = EPSILON_PRICE) {
    return (price >= epsilon && price <= 1000000000.0);
}
    bool IsValidPercentage(double percentage, double minPercent = 0.0, double maxPercent = 100.0) {
    return (percentage >= minPercent - EPSILON_PERCENTAGE && percentage <= maxPercent + EPSILON_PERCENTAGE);
}
    bool IsValidRatio(double ratio, double minRatio = 0.0, double maxRatio = 10.0) {
    return (ratio >= minRatio - EPSILON_RATIO && ratio <= maxRatio + EPSILON_RATIO);
}
    double CalculatePercentage(double part, double whole, double defaultValue = 0.0) {
        if(IsZero(whole, EPSILON_GENERAL)) return defaultValue;
    return (part / whole) * 100.0;
}
    double CalculateRatio(double numerator, double denominator, double defaultValue = 1.0) {
        if(IsZero(denominator, EPSILON_GENERAL)) return defaultValue;
    return numerator / denominator;
}
    double RoundToPip(double value) {
        double pipSize = (Digits == 3 || Digits == 5) ? Point * 10 : Point;
    if(IsZero(pipSize, EPSILON_GENERAL)) return value;
    return MathRound(value / pipSize) * pipSize;
}
    bool IsInRange(double value, double minVal, double maxVal, double epsilon = EPSILON_GENERAL) {
        return IsGreaterOrEqual(value, minVal, epsilon) && IsLessOrEqual(value, maxVal, epsilon);
}
    #endif
    // FLOATING_POINT_HELPER_MQH