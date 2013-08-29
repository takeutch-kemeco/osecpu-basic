/* 最初と最後がほぼ1に成らなければ異常
 */

dim a = 1;
print a;

a = a * 0.5; a = a * 0.5; a = a * 0.5; a = a * 0.5; a = a * 0.5; a = a * 0.5; a = a * 0.5;
print a;

a = a / 0.5; a = a / 0.5; a = a / 0.5; a = a / 0.5; a = a / 0.5; a = a / 0.5; a = a / 0.5;
print a;
