import os
import re

def main():
    # Load TikZ colors
    with open('docs/paper/figs/colors.tex', 'r', encoding='utf-8') as f:
        colors_code = f.read().strip()

    # Load individual TikZ figures
    with open('docs/paper/figs/fig-arch.tex', 'r', encoding='utf-8') as f:
        fig_arch_code = f.read().strip()
    with open('docs/paper/figs/fig-block.tex', 'r', encoding='utf-8') as f:
        fig_block_code = f.read().strip()
    with open('docs/paper/figs/fig-seq.tex', 'r', encoding='utf-8') as f:
        fig_seq_code = f.read().strip()
    with open('docs/paper/figs/fig-state.tex', 'r', encoding='utf-8') as f:
        fig_state_code = f.read().strip()
    with open('docs/paper/figs/fig-flow.tex', 'r', encoding='utf-8') as f:
        fig_flow_code = f.read().strip()

    # Load bibliography
    with open('docs/paper/refs-additions.bib', 'r', encoding='utf-8') as f:
        bib_code = f.read().strip()

    # Read the text template
    with open('docs/paper/smartlocker-10p.tex', 'r', encoding='utf-8') as f:
        full_text = f.read()

    # 1. Replace filecontents with updated 27 references
    fc_start = full_text.find('\\begin{filecontents*}')
    fc_end = full_text.find('\\end{filecontents*}') + len('\\end{filecontents*}')
    
    new_fc = f"\\begin{{filecontents*}}[overwrite]{{references.bib}}\n{bib_code}\n\\end{{filecontents*}}"
    full_text = full_text[:fc_start] + new_fc + full_text[fc_end:]

    # 2. Replace \\input{figs/colors.tex} with inlined colors_code
    full_text = full_text.replace('\\input{figs/colors.tex}', colors_code)

    # 3. Replace author block: remove * on Kieu Trong Khanh and footnote
    old_author_pat = re.compile(
        r'\\author\{%[\s\S]*?\\begin\{tabular\}\{ccc\}[\s\S]*?\\end\{tabular\}\}',
        re.MULTILINE
    )
    new_author = (
        r'\author{%' + '\n'
        r'\begin{tabular}{ccc}' + '\n'
        r'Duc Hoang Nguyen & Viet Tien Nguyen & Huy Hoang Nguyen \\' + '\n'
        r'{\small duchoang.nguyen103@fpt.edu.vn} & {\small tiennv@fpt.edu.vn} & {\small hoangnh@fpt.edu.vn} \\[8pt]' + '\n'
        r'Thanh Cao Nguyen & Thu Le & Kieu Trong Khanh \\' + '\n'
        r'{\small thanhnc@fpt.edu.vn} & {\small thulvm@fpt.edu.vn} & {\small khanhkt@fpt.edu.vn} \\[8pt]' + '\n'
        r'\multicolumn{3}{c}{FPT University, Ho Chi Minh Campus, Vietnam}' + '\n'
        r'\end{tabular}}'
    )
    full_text = old_author_pat.sub(lambda m: new_author, full_text, count=1)

    # 4. Inlining TikZ figures
    full_text = full_text.replace('\\input{figs/fig-arch.tex}', fig_arch_code)
    full_text = full_text.replace('\\input{figs/fig-block.tex}', fig_block_code)
    full_text = full_text.replace('\\input{figs/fig-seq.tex}', fig_seq_code)
    full_text = full_text.replace('\\input{figs/fig-state.tex}', fig_state_code)
    full_text = full_text.replace('\\input{figs/fig-flow.tex}', fig_flow_code)

    # 5. Replace Fig. 7 & 8 (ui-user and ui-staff) with clean unified Fig. 7 using existing images
    old_ui_block_pat = re.compile(
        r'% CHECK-FINAL: ui-user/ui-staff[\s\S]*?\\label\{fig:ui-staff\}\s*\\end\{figure\}',
        re.MULTILINE
    )
    new_ui_block = (
        r'\begin{figure}[!htbp]' + '\n'
        r'\centering' + '\n'
        r'\includegraphics[width=0.24\linewidth]{images/map-area.png}\hfill' + '\n'
        r'\includegraphics[width=0.24\linewidth]{images/booking-confirm.png}\hfill' + '\n'
        r'\includegraphics[width=0.24\linewidth]{images/dashboard.png}\hfill' + '\n'
        r'\includegraphics[width=0.24\linewidth]{images/alert-escalated.png}' + '\n'
        r'\caption{Web interface of SmartLocker: area map with slot occupancy (left), booking confirmation with pricing and refund rules (center-left), operator dashboard with real-time status and alerts (center-right), and escalated overdue alert with audit evidence (right).}' + '\n'
        r'\label{fig:ui}' + '\n'
        r'\end{figure}'
    )
    full_text = old_ui_block_pat.sub(lambda m: new_ui_block, full_text, count=1)

    # Update text referring to ui-user and ui-staff with regex
    ui_ref_pat = re.compile(
        r'\(Fig\.~\\ref\{fig:ui-user\}\),\s*while\s+staff\s+follow\s+devices,\s*revenue\s+and\s+alerts\s+from\s+the\s+dashboard\s+\(Fig\.~\\ref\{fig:ui-staff\}\)',
        re.MULTILINE
    )
    full_text = ui_ref_pat.sub(
        r', while staff follow devices, revenue and alerts from the dashboard (Fig.~\\ref{fig:ui})',
        full_text
    )

    # 6. Replace ml-eval.pdf figure in Section VI.B with Table IV (10-fold CV results) directly inside Section VI.B
    old_ml_fig_pat = re.compile(
        r'\\begin\{figure\}\[!htbp\]\s*\\centering\s*\\includegraphics\[[^\]]+\]\{images/ml-eval\.pdf\}[\s\S]*?\\label\{fig:mleval\}\s*\\end\{figure\}',
        re.MULTILINE
    )
    table_ml_code = (
        r'\begin{table}[!htbp]' + '\n'
        r'\renewcommand{\arraystretch}{1.1}' + '\n'
        r'\centering' + '\n'
        r'\small' + '\n'
        r'\caption{10-Fold Cross-Validation Results of the Evaluated Classifiers (Weighted Averages)}' + '\n'
        r'\label{tab:ml}' + '\n'
        r'\begin{tabular}{l c c c c c c}' + '\n'
        r'\hline' + '\n'
        r' & \multicolumn{4}{c}{Six classes} & \multicolumn{2}{c}{Binary} \\' + '\n'
        r'Model & Accuracy & Precision & Recall & F1 & Accuracy & F1 \\' + '\n'
        r'\hline' + '\n'
        r'Random Forest & 0.948 & 0.949 & 0.948 & 0.948 & 0.938 & 0.939 \\' + '\n'
        r'J48 (C4.5)    & 0.856 & 0.857 & 0.856 & 0.856 & 0.831 & 0.848 \\' + '\n'
        r'Naive Bayes   & 0.779 & 0.778 & 0.779 & 0.778 & 0.833 & 0.852 \\' + '\n'
        r'IBk ($k=5$)   & 0.977 & 0.978 & 0.977 & 0.977 & 0.975 & 0.975 \\' + '\n'
        r'\hline' + '\n'
        r'\end{tabular}' + '\n'
        r'\end{table}'
    )
    full_text = old_ml_fig_pat.sub(lambda m: table_ml_code, full_text, count=1)

    # Update text referring to fig:mleval
    mleval_ref_pat1 = re.compile(
        r'\(Fig\.~\\ref\{fig:mleval\}a\),\s*followed\s+by\s+Random\s+Forest\s+\(0\.948\s+and\s+0\.939\),\s*while\s+Naive\s+Bayes\s+is\s+the\s+weakest\s+model\s+in\s+the\s+six-class\s+setting\s+\(0\.778\);\s*accuracy,\s*precision\s+and\s+recall\s+of\s+every\s+model\s+are\s+listed\s+in\s+Table~\\ref\{tab:ml\}\s+in\s+the\s+appendix\.',
        re.MULTILINE
    )
    full_text = mleval_ref_pat1.sub(
        r'(Table~\\ref{tab:ml}), followed by Random Forest (0.948 and 0.939), while Naive Bayes is the weakest model in the six-class setting (0.778); accuracy, precision, recall and F1 of every model are listed in Table~\\ref{tab:ml}.',
        full_text
    )

    mleval_ref_pat2 = re.compile(
        r'\(F1\s+0\.936\s+and\s+0\.939,\s*Fig\.~\\ref\{fig:mleval\}b\)',
        re.MULTILINE
    )
    full_text = mleval_ref_pat2.sub(
        r'(F1 0.936 and 0.939)',
        full_text
    )

    # 7. Remove appendix block containing Table tab:ml
    old_appendix_pat = re.compile(
        r'\\appendix\[Full Cross-Validation Results\][\s\S]*?\\label\{tab:ml\}[\s\S]*?\\end\{table\}',
        re.MULTILINE
    )
    full_text = old_appendix_pat.sub('', full_text, count=1)

    # 8. Update Acknowledgment text referring to fig:mleval
    ack_ref_pat = re.compile(
        r'and\s+to\s+draw\s+the\s+diagrams\s+of\s+Fig\.~\\ref\{fig:arch\}\s+to\s+Fig\.~\\ref\{fig:flow\}\s+and\s+the\s+chart\s+of\s+Fig\.~\\ref\{fig:mleval\}\.',
        re.MULTILINE
    )
    full_text = ack_ref_pat.sub(
        r'and to draw the diagrams of Fig.~\\ref{fig:arch} to Fig.~\\ref{fig:flow}.',
        full_text
    )

    # 9. Update bibliography command to reference references.bib
    full_text = full_text.replace('\\bibliography{smartlocker-refs}', '\\bibliography{references}')

    # Save to target files
    with open('overleaf_package/main.tex', 'w', encoding='utf-8') as f:
        f.write(full_text)

    with open('docs/paper/smartlocker-10p.tex', 'w', encoding='utf-8') as f:
        f.write(full_text)

    print('main.tex updated successfully!')

if __name__ == '__main__':
    main()
