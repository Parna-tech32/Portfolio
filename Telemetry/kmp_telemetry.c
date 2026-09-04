#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX 10000

// U/D
void toPattern(double data[], int n, char pattern[]) {
    for (int i = 1; i < n; i++) {
        if (data[i] > data[i-1])
            pattern[i-1] = 'U';
        else
            pattern[i-1] = 'D';
    }
    pattern[n-1] = '\0';
}

// LPS
void computeLPS(char *pat, int m, int *lps) {
    int len = 0;
    lps[0] = 0;

    for (int i = 1; i < m; ) {
        if (pat[i] == pat[len]) {
            lps[i++] = ++len;
        } else {
            if (len != 0)
                len = lps[len - 1];
            else
                lps[i++] = 0;
        }
    }
}

void KMP(char *txt, char *pat) {
    int n = strlen(txt);
    int m = strlen(pat);

    int *lps = (int*)malloc(m * sizeof(int));
    computeLPS(pat, m, lps);

    int i = 0, j = 0;

    while (i < n) {
        if (txt[i] == pat[j]) {
            i++; j++;
        }

        if (j == m) {
            printf("✔ Anomaly detected at index: %d\n", i - j);
            j = lps[j - 1];
        } 
        else if (i < n && txt[i] != pat[j]) {
            if (j != 0)
                j = lps[j - 1];
            else
                i++;
        }
    }

    free(lps);
}

int readCSV(const char *filename, double data[]) {
    FILE *fp = fopen(filename, "r");
    if (!fp) {
        printf("Error opening file\n");
        return 0;
    }

    int i = 0;
    while (fscanf(fp, "%lf", &data[i]) != EOF) {
        i++;
    }

    fclose(fp);
    return i;
}

int main() {
    printf("Telemetry Anomaly Detection\n\n");

    double data[MAX];
    char cwd[1024];
    getcwd(cwd, sizeof(cwd));

    char filepath[2048];
    sprintf(filepath, "%s/telemetry.csv", cwd);

    int n = readCSV(filepath, data);

    if (n == 0) return 0;

    char text[MAX], pattern[MAX];
    toPattern(data, n, text);

    int start = 2149, end = 2349;
    double anomaly[MAX];

    int k = 0;
    for (int i = start; i < end; i++) {
        anomaly[k++] = data[i];
    }

    toPattern(anomaly, k, pattern);

    KMP(text, pattern);

    return 0;
}
