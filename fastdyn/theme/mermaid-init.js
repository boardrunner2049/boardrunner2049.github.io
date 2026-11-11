// Diagram colors come from the same CSS palette as the rest of the book.
(() => {
  const root = document.documentElement;
  const styles = getComputedStyle(root);
  const color = name => styles.getPropertyValue(name).trim();
  const isDark = () => getComputedStyle(root).getPropertyValue('--color-scheme').trim() === 'dark';
  const initialDark = isDark();

  mermaid.initialize({
    startOnLoad: true,
    securityLevel: 'strict',
    theme: 'base',
    themeVariables: {
      darkMode: initialDark,
      background: color('--bg'),
      primaryColor: color('--diagram-node-bg'),
      primaryTextColor: color('--fg'),
      primaryBorderColor: color('--diagram-border'),
      lineColor: color('--diagram-border'),
      secondaryColor: color('--sidebar-bg'),
      tertiaryColor: color('--quote-bg'),
      clusterBkg: color('--quote-bg'),
      clusterBorder: color('--diagram-border'),
      edgeLabelBackground: color('--bg'),
      fontFamily: color('--font-body'),
      fontSize: '15px'
    }
  });

  // Re-render when a reader changes between the light and dark palettes.
  // Watching the class also covers the Auto option in mdBook's theme menu.
  new MutationObserver(() => {
    if (isDark() !== initialDark) location.reload();
  }).observe(root, { attributes: true, attributeFilter: ['class'] });
})();
